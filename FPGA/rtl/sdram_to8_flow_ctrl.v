module sdram_to8_flow_ctrl(
    input             clk_100m,
    input             rst_n,
    
    input             to8_wrfull,
    input             to8_rdempty,
    input      [12:0] to8_wrusedw,
    output reg        sdram_rd_en,
    
    input      [9:0]  sdram_rd_usedw,
    input      [15:0] sdram_rd_data,
    output reg        to8_wr_en,
    output reg [15:0] to8_wr_data
);

parameter FIFO_LOW_THRESHOLD  = 13'd2000;
parameter FIFO_HIGH_THRESHOLD = 13'd5500;

wire to8_fifo_low = (to8_wrusedw < FIFO_LOW_THRESHOLD) && (to8_wrusedw > 0 || to8_rdempty);
wire to8_fifo_high = (to8_wrusedw >= FIFO_HIGH_THRESHOLD) || to8_wrfull;
wire sdram_data_valid = (sdram_rd_usedw > 10'd0) && !to8_wrfull;

always @(posedge clk_100m or negedge rst_n) begin
    if(!rst_n) begin
        sdram_rd_en <= 1'b0;
    end
    else begin
        if(to8_fifo_low)
            sdram_rd_en <= 1'b1;
        else if(to8_fifo_high)
            sdram_rd_en <= 1'b0;
    end
end

always @(posedge clk_100m or negedge rst_n) begin
    if(!rst_n) begin
        to8_wr_en <= 1'b0;
        to8_wr_data <= 16'd0;
    end
    else if(sdram_data_valid && sdram_rd_en) begin
        to8_wr_en <= 1'b1;
        to8_wr_data <= sdram_rd_data;
    end
    else begin
        to8_wr_en <= 1'b0;
        to8_wr_data <= to8_wr_data;
    end
end

endmodule
