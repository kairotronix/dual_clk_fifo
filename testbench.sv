`timescale 1ps/1ps
module testbench();

localparam FIFO_DSIZE = 8;
localparam FIFO_DEPTH = 16;
localparam FIFO_ALMOST_VAL = 2;
localparam FIFO_ALMOST_FULL = FIFO_DEPTH - FIFO_ALMOST_VAL;


localparam WR_CLK_FREQ_HZ = 100_000_000;
localparam WR_CLK_DELAY_NS = integer'(((1.0)/(real'(WR_CLK_FREQ_HZ*2)))*1_000_000_000);


localparam RD_CLK_FREQ_HZ = 10_000_000;
localparam RD_CLK_DELAY_NS = integer'(((1.0)/(real'(RD_CLK_FREQ_HZ*2)))*1_000_000_000);







logic                           wr_clk;
logic                           wr_resetn;
logic [FIFO_DSIZE-1:0]          wr_data;
logic                           wr_req;
logic                           wr_fifo_empty;
logic                           wr_fifo_almost_empty;
logic                           wr_fifo_full;
logic                           wr_fifo_almost_full;
logic [$clog2(FIFO_DSIZE):0]    wr_fifo_occupied;



logic                           rd_clk;
logic                           rd_resetn;
logic [FIFO_DSIZE-1:0]          rd_data;
logic                           rd_req;
logic                           rd_fifo_empty;
logic                           rd_fifo_almost_empty;
logic                           rd_fifo_full;
logic                           rd_fifo_almost_full;
logic [$clog2(FIFO_DSIZE):0]    rd_fifo_occupied;

logic wr_clk_raw;
task initial_reset;
    wr_clk_raw <= '0;
    rd_clk <= '0;
    wr_clk <= '0;
    wr_resetn <= '0;
    rd_resetn <= '0;
    @(posedge rd_clk);
    @(posedge wr_clk);
    rd_resetn <= '1;
    wr_resetn <= '1;
endtask

always #(WR_CLK_DELAY_NS) wr_clk_raw = ~wr_clk_raw;
always #(RD_CLK_DELAY_NS) rd_clk = ~rd_clk;

always #(2) wr_clk = wr_clk_raw;

logic startRead_w;
always_ff @(posedge wr_clk)
begin
    if(wr_resetn == '0)
    begin
        wr_req <= '0;
        wr_data <= '0;
        startRead_w <= '0;
    end
    else
    begin
        if(wr_fifo_occupied < (FIFO_DEPTH-5))
        begin
            wr_data <= wr_data + 1;
            wr_req <= '1;
        end
        else
        begin
            wr_req <= '0;
            wr_data <= wr_data + 1;
            startRead_w <= '1;
        end
        if(wr_fifo_empty)
            startRead_w <= '0;
    end
end

logic startRead_flip;
logic startRead_flop;
always_ff @(posedge rd_clk)
begin
    if(rd_resetn == '0)
    begin
        rd_req <= '0;
        startRead_flip <= '0;
        startRead_flop <= '0;
    end
    else
    begin
        startRead_flip <= startRead_w;
        startRead_flop <= startRead_flip;
        if(startRead_flop)
        begin
            if(!rd_fifo_empty)
            begin
                rd_req <= '1;
            end
        end
    end
end


initial
begin
    initial_reset();
end


dual_clk_fifo #(
    .DSIZE(FIFO_DSIZE),
    .DEPTH(FIFO_DEPTH),
    .ALMOST_EMPTY_VALUE(FIFO_ALMOST_VAL),
    .ALMOST_FULL_VALUE(FIFO_ALMOST_FULL)
)
dut
(
    .wr_clk(wr_clk),
    .wr_resetn(wr_resetn),
    .wr_data_i(wr_data),
    .wr_req_i(wr_req),
    .wr_fifo_empty_o(wr_fifo_empty),
    .wr_fifo_almost_empty_o(wr_fifo_almost_empty),
    .wr_fifo_full_o(wr_fifo_full),
    .wr_fifo_almost_full_o(wr_fifo_almost_full),
    .wr_fifo_occupied_o(wr_fifo_occupied),
    .rd_clk(rd_clk),
    .rd_resetn(rd_resetn),
    .rd_data_o(rd_data),
    .rd_req_i(rd_req),
    .rd_fifo_empty_o(rd_fifo_empty),
    .rd_fifo_almost_empty_o(rd_fifo_almost_empty),
    .rd_fifo_full_o(rd_fifo_full),
    .rd_fifo_almost_full_o(rd_fifo_almost_full),
    .rd_fifo_occupied_o(rd_fifo_occupied)
);

endmodule : testbench
