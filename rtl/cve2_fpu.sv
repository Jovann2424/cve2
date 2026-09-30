// Copyright (c) 2026
// Licensed under the Apache License, Version 2.0.
// SPDX-License-Identifier: Apache-2.0

`include "HardFloat_consts.vi"
`include "HardFloat_specialize.vi"

// RV32F single-precision execution unit. Arithmetic and IEEE-754 exception
// handling are provided by Berkeley HardFloat Release 1.
module cve2_fpu (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        start_i,
  input  logic [31:0] instr_i,
  input  logic [31:0] f_rs1_i,
  input  logic [31:0] f_rs2_i,
  input  logic [31:0] f_rs3_i,
  input  logic [31:0] x_rs1_i,
  input  logic [2:0]  frm_i,
  output logic        done_o,
  output logic        busy_o,
  output logic        writes_fpr_o,
  output logic        writes_xpr_o,
  output logic [4:0]  rd_o,
  output logic [31:0] result_o,
  output logic [4:0]  flags_o
);
  localparam logic [6:0] OP_MADD     = 7'h43;
  localparam logic [6:0] OP_MSUB     = 7'h47;
  localparam logic [6:0] OP_NMSUB    = 7'h4b;
  localparam logic [6:0] OP_NMADD    = 7'h4f;
  localparam logic [6:0] OP_FP       = 7'h53;
  localparam logic [7:0] FADD_S      = 8'h00;
  localparam logic [7:0] FSUB_S      = 8'h04;
  localparam logic [7:0] FMUL_S      = 8'h08;
  localparam logic [7:0] FDIV_S      = 8'h0c;
  localparam logic [7:0] FSQRT_S     = 8'h2c;
  localparam logic [7:0] FSGNJ_S     = 8'h10;
  localparam logic [7:0] FMINMAX_S   = 8'h14;
  localparam logic [7:0] FCVT_W_S    = 8'h60;
  localparam logic [7:0] FCVT_S_W    = 8'h68;
  localparam logic [7:0] FMV_FCLASS  = 8'h70;
  localparam logic [7:0] FMV_W_X     = 8'h78;
  localparam logic [7:0] FCMP_S      = 8'h50;

  logic [2:0] rm;
  logic [32:0] rec_a, rec_b, rec_c;
  logic [32:0] rec_result;
  logic [31:0] ieee_result;
  logic [4:0] itof_flags;
  logic [31:0] cvt_result;
  logic [2:0] int_flags;
  logic cmp_lt, cmp_eq, cmp_gt, cmp_unordered;
  logic [4:0] cmp_flags;
  logic div_in_ready, div_out_valid, div_sqrt;
  logic [32:0] div_result;
  logic [4:0] div_result_flags;
  logic [32:0] add_result, mul_result, fma_result, itof_result;
  logic [4:0] add_exception, mul_exception, fma_exception;
  logic div_instruction, fp_instruction, fp_to_x;
  logic [4:0] class_result;
  logic [31:0] fmv_class_result;
  logic unused_div_in_ready;

  assign rm = (instr_i[14:12] == 3'b111) ? frm_i : instr_i[14:12];
  assign fp_instruction = (instr_i[6:0] == OP_FP) ||
                          (instr_i[6:0] inside {OP_MADD, OP_MSUB, OP_NMSUB, OP_NMADD});
  assign div_instruction = (instr_i[6:0] == OP_FP) &&
                           ((instr_i[31:25] == FDIV_S[6:0]) ||
                            (instr_i[31:25] == FSQRT_S[6:0]));
  assign div_sqrt = instr_i[31:25] == FSQRT_S[6:0];
  assign fp_to_x = (instr_i[6:0] == OP_FP) &&
                   ((instr_i[31:25] == FCVT_W_S[6:0]) ||
                    (instr_i[31:25] == FCMP_S[6:0]) ||
                    (instr_i[31:25] == FMV_FCLASS[6:0] && instr_i[24:20] == 5'b0));

  fNToRecFN #(.expWidth(8), .sigWidth(24)) f_to_rec_a (.in(f_rs1_i), .out(rec_a));
  fNToRecFN #(.expWidth(8), .sigWidth(24)) f_to_rec_b (.in(f_rs2_i), .out(rec_b));
  fNToRecFN #(.expWidth(8), .sigWidth(24)) f_to_rec_c (.in(f_rs3_i), .out(rec_c));

  addRecFN #(.expWidth(8), .sigWidth(24)) add_sub_unit (
    .control(`flControl_default), .subOp(instr_i[30]), .a(rec_a), .b(rec_b),
    .roundingMode(rm), .out(add_result), .exceptionFlags(add_exception)
  );
  mulRecFN #(.expWidth(8), .sigWidth(24)) mul_unit (
    .control(`flControl_default), .a(rec_a), .b(rec_b), .roundingMode(rm),
    .out(mul_result), .exceptionFlags(mul_exception)
  );
  mulAddRecFN #(.expWidth(8), .sigWidth(24)) fma_unit (
    .control(`flControl_default),
    .op(instr_i[6:0] == OP_MADD  ? 2'b00 :
         instr_i[6:0] == OP_MSUB  ? 2'b01 :
         instr_i[6:0] == OP_NMSUB ? 2'b10 : 2'b11),
    .a(rec_a), .b(rec_b), .c(rec_c), .roundingMode(rm),
    .out(fma_result), .exceptionFlags(fma_exception)
  );
  compareRecFN #(.expWidth(8), .sigWidth(24)) compare_unit (
    .a(rec_a), .b(rec_b), .signaling(instr_i[14:12] != 3'b010),
    .lt(cmp_lt), .eq(cmp_eq), .gt(cmp_gt), .unordered(cmp_unordered),
    .exceptionFlags(cmp_flags)
  );
  recFNToIN #(.expWidth(8), .sigWidth(24), .intWidth(32)) rec_to_int (
    .control(`flControl_default), .in(rec_a), .roundingMode(rm),
    .signedOut(instr_i[20] == 1'b0), .out(cvt_result), .intExceptionFlags(int_flags)
  );
  iNToRecFN #(.intWidth(32), .expWidth(8), .sigWidth(24)) int_to_rec (
    .control(`flControl_default), .signedIn(instr_i[20] == 1'b0), .in(x_rs1_i),
    .roundingMode(rm), .out(itof_result), .exceptionFlags(itof_flags)
  );
  recFNToFN #(.expWidth(8), .sigWidth(24)) rec_to_ieee (
    .in(rec_result), .out(ieee_result)
  );
  divSqrtRecFN_small #(.expWidth(8), .sigWidth(24)) div_sqrt_unit (
    .nReset(rst_ni), .clock(clk_i), .control(`flControl_default),
    .inReady(div_in_ready), .inValid(start_i && div_instruction),
    .sqrtOp(div_sqrt), .a(rec_a), .b(rec_b), .roundingMode(rm),
    .outValid(div_out_valid), .sqrtOpOut(), .out(div_result),
    .exceptionFlags(div_result_flags)
  );
  assign unused_div_in_ready = div_in_ready;

  always_comb begin
    class_result = '0;
    if (f_rs1_i[30:23] == 8'hff) begin
      if (f_rs1_i[22:0] != 0) class_result[f_rs1_i[22] ? 9 : 8] = 1'b1;
      else class_result[f_rs1_i[31] ? 0 : 7] = 1'b1;
    end else if (f_rs1_i[30:23] == 0) begin
      if (f_rs1_i[22:0] == 0) class_result[f_rs1_i[31] ? 3 : 4] = 1'b1;
      else class_result[f_rs1_i[31] ? 2 : 5] = 1'b1;
    end else begin
      class_result[f_rs1_i[31] ? 1 : 6] = 1'b1;
    end

    fmv_class_result = '0;
    unique case (instr_i[31:25])
      FCVT_W_S[6:0]: fmv_class_result = cvt_result;
      FMV_FCLASS[6:0]: begin
        if (instr_i[14:12] == 3'b001) fmv_class_result = {27'b0, class_result};
        else fmv_class_result = f_rs1_i;
      end
      default: fmv_class_result = f_rs1_i;
    endcase

    rec_result = add_result;
    flags_o = '0;
    result_o = ieee_result;
    writes_fpr_o = fp_instruction;
    writes_xpr_o = fp_to_x;
    rd_o = instr_i[11:7];

    if (instr_i[6:0] inside {OP_MADD, OP_MSUB, OP_NMSUB, OP_NMADD}) begin
      rec_result = fma_result;
      flags_o = fma_exception;
    end else begin
      unique case (instr_i[31:25])
        FADD_S[6:0], FSUB_S[6:0]: begin rec_result = add_result; flags_o = add_exception; end
        FMUL_S[6:0]: begin rec_result = mul_result; flags_o = mul_exception; end
        FDIV_S[6:0], FSQRT_S[6:0]: begin
          rec_result = div_result;
          flags_o = div_result_flags;
        end
        FSGNJ_S[6:0]: begin
          unique case (instr_i[14:12])
            3'b000: result_o = {f_rs2_i[31], f_rs1_i[30:0]};
            3'b001: result_o = {~f_rs2_i[31], f_rs1_i[30:0]};
            3'b010: result_o = {f_rs1_i[31] ^ f_rs2_i[31], f_rs1_i[30:0]};
            default: result_o = 32'b0;
          endcase
        end
        FMINMAX_S[6:0]: begin
          if (cmp_unordered) begin
            if ((f_rs1_i[30:23] == 8'hff) && (f_rs1_i[22:0] != 0) &&
                (f_rs2_i[30:23] == 8'hff) && (f_rs2_i[22:0] != 0))
              result_o = 32'h7fc0_0000;
            else result_o = (f_rs1_i[30:23] == 8'hff && f_rs1_i[22:0] != 0) ? f_rs2_i : f_rs1_i;
          end else if (f_rs1_i[30:0] == 0 && f_rs2_i[30:0] == 0) begin
            result_o = instr_i[12] ? {1'b0, 31'b0} : {f_rs1_i[31] | f_rs2_i[31], 31'b0};
          end else result_o = (instr_i[12] ? (cmp_gt ? f_rs1_i : f_rs2_i) :
                                              (cmp_lt ? f_rs1_i : f_rs2_i));
          flags_o = {4'b0,
            ((f_rs1_i[30:23] == 8'hff) && (f_rs1_i[22:0] != 0) && !f_rs1_i[22]) ||
            ((f_rs2_i[30:23] == 8'hff) && (f_rs2_i[22:0] != 0) && !f_rs2_i[22])};
        end
        FCVT_W_S[6:0]: begin
          result_o = cvt_result;
          flags_o = {int_flags[2] | int_flags[1], 3'b0, int_flags[0]};
        end
        FCVT_S_W[6:0]: begin rec_result = itof_result; flags_o = itof_flags; end
        FCMP_S[6:0]: begin
          unique case (instr_i[14:12])
            3'b010: result_o = {31'b0, cmp_eq};
            3'b001: result_o = {31'b0, cmp_lt};
            3'b000: result_o = {31'b0, cmp_lt | cmp_eq};
            default: result_o = '0;
          endcase
          flags_o = cmp_flags;
        end
        FMV_FCLASS[6:0]: result_o = fmv_class_result;
        FMV_W_X[6:0]: result_o = x_rs1_i;
        default: begin result_o = 32'b0; flags_o = '0; end
      endcase
    end
    if (instr_i[6:0] inside {OP_MADD, OP_MSUB, OP_NMSUB, OP_NMADD} ||
        instr_i[31:25] inside {FADD_S[6:0], FSUB_S[6:0], FMUL_S[6:0],
                               FDIV_S[6:0], FSQRT_S[6:0], FCVT_S_W[6:0]})
      result_o = ieee_result;
    if (instr_i[31:25] == FMINMAX_S[6:0] || instr_i[31:25] == FSGNJ_S[6:0] ||
        instr_i[31:25] == FMV_FCLASS[6:0] || instr_i[31:25] == FMV_W_X[6:0])
      writes_fpr_o = 1'b1;
    if (instr_i[31:25] == FCVT_W_S[6:0] || instr_i[31:25] == FCMP_S[6:0] ||
        (instr_i[31:25] == FMV_FCLASS[6:0] && instr_i[24:20] == 0))
      writes_fpr_o = 1'b0;
    if (instr_i[31:25] == FCMP_S[6:0] ||
        (instr_i[31:25] == FMV_FCLASS[6:0] && instr_i[14:12] == 3'b001))
      writes_xpr_o = 1'b1;
    if (instr_i[31:25] == FMV_W_X[6:0]) flags_o = '0;
    if (instr_i[31:25] == FMV_FCLASS[6:0] || instr_i[31:25] == FSGNJ_S[6:0]) flags_o = '0;
  end

  assign done_o = div_instruction ? div_out_valid : start_i;
  assign busy_o = div_instruction && !div_out_valid;

endmodule
