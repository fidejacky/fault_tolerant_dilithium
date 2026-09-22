module trm_fdse #(
    parameter INIT = 1'b0
)(
    output wire Q,
    output wire fault,
    input wire C,
    input wire CE,
    input wire D,
    input wire S
);

(*KEEP = "true" *) wire q_a,q_b,q_c;

(* DONT_TOUCH = "true" *)
FDSE #(.INIT(INIT)) u_ff_a (
    .Q(q_a),
    .C(C),
    .CE(CE),
    .D(D),
    .S(S)
);

(* DONT_TOUCH = "true" *)
FDSE #(.INIT(INIT)) u_ff_b (
    .Q(q_b),
    .C(C),
    .CE(CE),
    .D(D),
    .S(S)
);

(* DONT_TOUCH = "true" *)
FDSE #(.INIT(INIT)) u_ff_c (
    .Q(q_c),
    .C(C),
    .CE(CE),
    .D(D),
    .S(S)
);

function vote3;
    input a,b,c;
    begin
        vote3 = (a&b)|(a&c)|(b&c);
    end
endfunction

(* KEEP = "true" *) wire q_voted = vote3(q_a, q_b, q_c);
assign Q     = q_voted;
assign fault = (q_a ^ q_b) | (q_b ^ q_c);

endmodule