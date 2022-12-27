/*
    Kairotronix, 2022.
    Name: dual_clk_fifo
    Description:
        Asynchronous FIFO with separate read/write clocks and flags.
    
    NOTE:
        This is provided AS-IS. If there are issues feel free to let me know through Github, however
    there will be no support given.
*/

module dual_clk_fifo #(
    parameter                       DSIZE = 16,                 //  Data size
    parameter                       DEPTH = 128,                //  Number of elements in the FIFO, needs to be a power of 2.
    parameter                       ALMOST_EMPTY_VALUE = 4,
    parameter                       ALMOST_FULL_VALUE = 123
)
(
    /* Write Ports */
    input logic                     wr_clk,
    input logic                     wr_resetn,
    input logic [DSIZE-1:0]         wr_data_i,
    input logic                     wr_req_i,
    output logic                    wr_fifo_empty_o,
    output logic                    wr_fifo_almost_empty_o,
    output logic                    wr_fifo_full_o,
    output logic                    wr_fifo_almost_full_o,
    output logic [$clog2(DEPTH):0]  wr_fifo_occupied_o,         //  Number of elements in the FIFO (in write clock domain)

    /* Read Ports */
    input logic                     rd_clk,
    input logic                     rd_resetn,
    output logic [DSIZE-1:0]        rd_data_o,
    input logic                     rd_req_i,
    output logic                    rd_fifo_empty_o,
    output logic                    rd_fifo_almost_empty_o,
    output logic                    rd_fifo_full_o,
    output logic                    rd_fifo_almost_full_o,
    output logic [$clog2(DEPTH):0]  rd_fifo_occupied_o          //  Number of elements in the FIFO (in read clock domain)
);

//  Used for determining how many elements are in the FIFO.
function int abs(int value);
    return (value >= 0) ? value : -value;
endfunction


localparam PTR_SIZE = $clog2(DEPTH);

//  Write pointer + crossing clock domains to read clock
logic [PTR_SIZE:0] wr_pointer, wr_pointer_g, wr_pointer_flip, wr_pointer_flop;
logic [PTR_SIZE:0] wr_pointer_r;
//  Read pointer + crossing clock domains to write clock
logic [PTR_SIZE:0] rd_pointer, rd_pointer_g, rd_pointer_flip, rd_pointer_flop;
logic [PTR_SIZE:0] rd_pointer_w;
//  Zero extended read pointer for math operations
logic [PTR_SIZE+1:0] rd_ptr_chk, wr_ptr_chk;
logic [PTR_SIZE+1:0] rd_ptr_chk_w, wr_ptr_chk_r;

//  Main FIFO memory/RAM
logic [DSIZE-1:0] mem [DEPTH-1:0];

//  Zero extend the pointers for occupied check (write domain)
assign rd_ptr_chk_w =  {1'b0, rd_pointer_w};
assign wr_ptr_chk = {1'b0, wr_pointer};
//  How many elements we have is simply abs(read_ptr - write_ptr). 
assign wr_fifo_occupied_o = $unsigned(abs($signed(rd_ptr_chk_w - wr_ptr_chk)));
assign wr_fifo_full_o = (wr_fifo_occupied_o == (DEPTH));
assign wr_fifo_empty_o = (wr_fifo_occupied_o == '0);
assign wr_fifo_almost_full_o = (wr_fifo_occupied_o >= ALMOST_FULL_VALUE);
assign wr_fifo_almost_empty_o = (wr_fifo_occupied_o <= ALMOST_EMPTY_VALUE);

//  Zero extend the pointers for occupied check (read domain)
assign wr_ptr_chk_r =  {1'b0, wr_pointer_r};
assign rd_ptr_chk = {1'b0, rd_pointer};
//  How many elements we have is simply abs(read_ptr - write_ptr). 
assign rd_fifo_occupied_o = $unsigned(abs($signed(wr_ptr_chk_r - rd_ptr_chk)));
assign rd_fifo_empty_o = (rd_fifo_occupied_o == '0);
assign rd_fifo_full_o = (rd_fifo_occupied_o == (DEPTH));
assign rd_fifo_almost_empty_o = (rd_fifo_occupied_o <= ALMOST_EMPTY_VALUE);
assign rd_fifo_almost_full_o = (rd_fifo_occupied_o >= ALMOST_FULL_VALUE);

//  Data output assigned at read pointer index. NOTE: This should probably be double-flopped on the user-side?
assign rd_data_o = mem[rd_pointer[PTR_SIZE-1:0]];

//  Write logic
integer i;
always @(posedge wr_clk)
begin
    if(wr_resetn == '0)
    begin
        wr_pointer <= '0;
        //  Reset to 0
        for(i = 0; i < DEPTH; i = i + 1)
        begin
            mem[i] <= '0;
        end
    end
    else
    begin
        //  Only write when the FIFO isn't full (and there's a request)
        if(wr_req_i && !wr_fifo_full_o)
        begin
            //  Pointer is 1-bit over for checking, so we need to limit it to the size of the memory for writes.
            mem[wr_pointer[PTR_SIZE-1:0]] <= wr_data_i;
            wr_pointer <= wr_pointer + 1;
        end
    end
end

//  Begin CDC for read_pointer
bin2gray #(
    .N(PTR_SIZE+1)
)
b2g_rdPointer
(
    .binary(rd_pointer),
    .gray(rd_pointer_g)
);
//  Read pointer, synchronized to write
always @(posedge wr_clk)
begin
    if(wr_resetn == '0)
    begin
        rd_pointer_flip <= '0;
        rd_pointer_flop <= '0;
    end
    else
    begin
        rd_pointer_flip <= rd_pointer_g;
        rd_pointer_flop <= rd_pointer_flip;
    end
end

gray2bin #(
    .N(PTR_SIZE+1)
)
g2b_rdPointer
(
    .gray(rd_pointer_flop),
    .binary(rd_pointer_w)
);
//  End CDC for read_pointer


//  Read logic
always @(posedge rd_clk)
begin
    if(rd_resetn == '0)
    begin
        rd_pointer <= '0;
    end
    else
    begin
        //  Only increment the pointer when we get a request and the FIFO isn't empty.
        if(!rd_fifo_empty_o && rd_req_i)
        begin
            rd_pointer <= rd_pointer + 1;
        end
    end
end

//  Begin CDC for write_pointer
bin2gray #(
    .N(PTR_SIZE+1)
)
b2g_wrPointer
(
    .binary(wr_pointer),
    .gray(wr_pointer_g)
);

//  Write pointer, synchronized to read
always @(posedge rd_clk)
begin
    if(rd_resetn == '0)
    begin
        wr_pointer_flip <= '0;
        wr_pointer_flop <= '0;
    end
    else
    begin
        wr_pointer_flip <= wr_pointer_g;
        wr_pointer_flop <= wr_pointer_flip;
    end
end

gray2bin #(
    .N(PTR_SIZE+1)
)
g2b_wrPointer
(
    .gray(wr_pointer_flop),
    .binary(wr_pointer_r)
);

//  End CDC for write_pointer

endmodule : dual_clk_fifo


module bin2gray #(parameter N = 5)
(
    input logic [N-1:0]     binary,
    output logic [N-1:0]    gray
);

int i;

always_comb
begin
    gray[N-1] = binary[N-1];
    for(i = N-1; i > 0; i = i - 1)
    begin
        gray[i-1] = binary[i] ^ binary[i-1];
    end
end
endmodule : bin2gray

module gray2bin #(parameter N = 5)
(
    input logic [N-1:0]     gray,
    output logic [N-1:0]    binary
);

genvar i;

generate
    for(i = 0; i < N; i = i + 1)
    begin
        assign binary[i] = ^ gray[N-1:i];
    end
endgenerate

endmodule : gray2bin