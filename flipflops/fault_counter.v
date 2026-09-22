module fault_counter #(
    parameter WIDTH   = 32,
    parameter THR_100 = 10
)(
    input  wire          clk,
    input  wire          rst,
    input  wire          fault,
    output reg  [WIDTH-1:0] count,
    output reg           trigger_rst
);

wire fault_s = (fault === 1'b1); //useful to avoid X propagation in simulation

reg window [0:99];
reg [WIDTH-1:0] running_total;
integer j;

initial begin
    count         = {WIDTH{1'b0}};
    running_total = {WIDTH{1'b0}};
    trigger_rst   = 1'b0;
    for (j = 0; j < 100; j = j + 1)
        window[j] = 0;
end

always @(posedge clk) begin
    if (rst) begin
        count         <= {WIDTH{1'b0}};
        running_total <= {WIDTH{1'b0}};
        trigger_rst   <= 1'b0;
        for (j = 0; j < 100; j = j + 1)
            window[j] <= 0;
    end else begin
        if (fault_s)
            count <= count + 1'b1;

        // sliding window: drop oldest cycle, add current
        running_total <= running_total + fault_s - window[99];
        for (j = 99; j > 0; j = j - 1)
            window[j] <= window[j-1];
        window[0] <= fault_s;

        trigger_rst <= (running_total + fault_s - window[99] >= THR_100);
    end
end

endmodule
