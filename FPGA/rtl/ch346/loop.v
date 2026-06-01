module loop(
    input           wire_clk            ,
    input           wire_rstn           ,
    
    input           wire_module_en      ,
    input [1:0]     wire_len_sel        ,
    input [1:0]     wire_speed_sel      ,
    
    output          wire_cs_n           ,
    output          wire_addr           ,
    output          wire_wr_n           ,
    output          wire_rd_n           ,
    input  [7:0]    wire_data_i         ,
    output [7:0]    wire_data_o         ,
    output          wire_data_oe        ,

    output          wire_busy           ,
    input           wire_loop_en        ,
    input           wire_rdne_n         ,
    input           wire_wrnf_n      
);
wire [7:0]  wire_ram_wr_data;
wire [11:0] wire_ram_addr   ;
wire        wire_ram_wr_en  ;
wire [7:0]  wire_ram_rd_data;
reg reg_arb;

reg  [15:0] reg_data_len    ;
wire [2 :0] wire_div_num    ;
reg  [4 :0] reg_burst_num   ;
reg  [4 :0] reg_burst_cnt   ;
reg  [15:0] reg_offset_addr ;

assign wire_div_num =   wire_speed_sel == 2'd0 ? (8 - 1) : // fclk/8
                        wire_speed_sel == 2'd1 ? (4 - 1) : // fclk/4
                                                 (2 - 1) ; // fclk/2

always @(posedge wire_clk) begin
    reg_data_len <= 516;
    // reg_data_len <= wire_len_sel == 2'd0 ? 512  :
                    // wire_len_sel == 2'd1 ? 1024 :
                    // wire_len_sel == 2'd2 ? 2048 : 4096;
end

always @(posedge wire_clk) begin
    reg_burst_num <= wire_len_sel == 2'd0 ? 16  :
                     wire_len_sel == 2'd1 ? 8   :
                     wire_len_sel == 2'd2 ? 4   : 2;
end

always @(posedge wire_clk) begin
    // reg_offset_addr <= reg_data_len * reg_burst_cnt;
    reg_offset_addr <= 516 * reg_burst_cnt;
end



//--state machine
parameter ST_IDLE   = 0;
parameter ST_CMD    = 1;
parameter ST_OFFSET = 2;
parameter ST_LEN    = 3;
parameter ST_INDEX  = 4;
parameter ST_RD_DLY = 5;
parameter ST_DATA   = 6;
parameter ST_END    = 7;

reg [2:0] reg_cur_state;
reg [2:0] reg_nxt_state;

reg         reg_cs          ;
reg         reg_wr          ;
reg         reg_rd          ;
reg         reg_addr        ;
reg [7:0]   reg_data        ;
reg [2:0]   reg_clk_cnt     ;

reg [2:0]   reg_cmd_dly_cnt ;
reg [1:0]   reg_offset_cnt  ;
reg [1:0]   reg_len_cnt     ;
reg [1:0]   reg_index_cnt   ;
reg [15:0]  reg_data_cnt    ;
reg [5:0]   reg_dly_cnt     ;

// reg [31:0] reg_frame_cnt;

wire wire_st_chg;
assign wire_st_chg = reg_cur_state != reg_nxt_state;
assign wire_busy = reg_cur_state != ST_IDLE;

always @(posedge wire_clk or negedge wire_rstn) begin
    if(~wire_rstn)
        reg_cur_state <= ST_IDLE;
    else
        reg_cur_state <= reg_nxt_state;
end


always @(posedge wire_clk or negedge wire_rstn) begin
    if(~wire_rstn)
        reg_nxt_state <= ST_IDLE;
    else begin
        case(reg_cur_state)
            ST_IDLE  :  begin
                            if(wire_module_en & (~reg_arb & ~wire_rdne_n | reg_arb & ~wire_wrnf_n))
                                reg_nxt_state <= ST_CMD;
                        end
            ST_CMD   :  begin
                            if(reg_clk_cnt >= wire_div_num & (&reg_cmd_dly_cnt))
                                reg_nxt_state <= ST_OFFSET;
                        end
            ST_OFFSET:  begin
                            if(reg_clk_cnt >= wire_div_num & reg_offset_cnt == 1)
                                reg_nxt_state <= ST_LEN;
                        end
            ST_LEN   :  begin
                            if(reg_clk_cnt >= wire_div_num & reg_len_cnt == 1)
                                reg_nxt_state <= ST_RD_DLY;
                        end
            ST_RD_DLY:  begin
                            if(reg_clk_cnt >= wire_div_num & (&reg_dly_cnt[3:0]))
                                reg_nxt_state <= ST_INDEX;
                        end
            ST_INDEX :  begin
                            if(reg_clk_cnt >= wire_div_num & reg_index_cnt == 3)
                                reg_nxt_state <= ST_DATA;
                        end
            ST_DATA  :  begin
                            if(reg_clk_cnt >= wire_div_num & reg_data_cnt == reg_data_len - 1)
                                reg_nxt_state <= ST_END;
                        end
            ST_END   :  begin
                            if(&reg_dly_cnt)
                                reg_nxt_state <= ST_IDLE;
                        end
            default  :  reg_nxt_state <= ST_IDLE;
        endcase
    end
end

always @(posedge wire_clk or negedge wire_rstn) begin
    if(~wire_rstn)
        reg_clk_cnt <= 0;
    else begin
        if(reg_cur_state != ST_IDLE) begin
            if(reg_clk_cnt >= wire_div_num)
                reg_clk_cnt <= 0;
            else if(~wire_st_chg)
                reg_clk_cnt <= reg_clk_cnt + 1;
        end
        else 
            reg_clk_cnt <= 0;
    end
end

always @(posedge wire_clk or negedge wire_rstn) begin
    if(~wire_rstn) begin
        reg_cs          <= 0;
        reg_wr          <= 0;
        reg_rd          <= 0;
        reg_addr        <= 0;
        reg_data        <= 0;
        
        reg_cmd_dly_cnt <= 0;
        reg_offset_cnt  <= 0;
        reg_len_cnt     <= 0;
        reg_index_cnt   <= 0;
        reg_data_cnt    <= 0;
        reg_dly_cnt     <= 0;
    end
    else begin
        case(reg_cur_state)
            ST_IDLE  :  begin
                            reg_cs          <= 0;
                            reg_wr          <= 0;
                            reg_rd          <= 0;
                            reg_addr        <= 0;
                            reg_data        <= 0;
                            
                            reg_cmd_dly_cnt <= 0;
                            reg_offset_cnt  <= 0;
                            reg_len_cnt     <= 0;
                            reg_index_cnt   <= 0;
                            reg_data_cnt    <= 0;
                            reg_dly_cnt     <= 0;
                        end
            ST_CMD   :  begin
                            reg_cs <= 1;
                            // reg_wr <= reg_cmd_dly_cnt == 1 | reg_cmd_dly_cnt == 2;
                            reg_wr <= reg_cmd_dly_cnt != 0 & reg_cmd_dly_cnt != 7;
                            reg_addr <= (reg_cmd_dly_cnt != 0 & reg_cmd_dly_cnt != 7) | (reg_cmd_dly_cnt == 0 & reg_clk_cnt == 3) | (reg_cmd_dly_cnt == 7 & reg_clk_cnt <= 2);
                            reg_data <= reg_arb ? 8'haa : 8'hbb;
                            if(reg_clk_cnt >= wire_div_num)
                                reg_cmd_dly_cnt <= reg_cmd_dly_cnt + 1;
                        end
            ST_OFFSET:  begin
                            reg_wr <= reg_clk_cnt <= wire_div_num[2:1] & (~wire_st_chg);
                            reg_addr <= 0;
                            reg_data <= reg_offset_cnt == 0 ? reg_offset_addr[7:0] : reg_offset_addr[15:8];
                            if(reg_clk_cnt >= wire_div_num)
                                reg_offset_cnt <= reg_offset_cnt + 1;
                            
                        end
            ST_LEN   :  begin
                            reg_wr <= reg_clk_cnt <= wire_div_num[2:1] & (~wire_st_chg);
                            reg_data <= reg_len_cnt == 0 ? reg_data_len[7:0] : reg_data_len[15:8];
                            if(reg_clk_cnt >= wire_div_num)
                                reg_len_cnt <= reg_len_cnt + 1;
                        end
            ST_RD_DLY:  begin
                            reg_wr <= 0;
                            reg_rd <= 0;
                            if(reg_clk_cnt >= wire_div_num)
                                reg_dly_cnt <= reg_dly_cnt + 1;
                        end
            ST_INDEX :  begin
                            reg_rd <= ~reg_arb & reg_clk_cnt > wire_div_num[2:1];
                            reg_wr <= reg_arb & reg_clk_cnt <= wire_div_num[2:1] & (~wire_st_chg);
                            reg_data <= reg_arb ? wire_ram_rd_data : 0;
							// reg_data <= reg_arb ? (reg_index_cnt == 1 ? 8'h02 : 8'h00) : 0;
                            if(reg_clk_cnt >= wire_div_num) begin
                                reg_index_cnt <= reg_index_cnt + 1;
                                // if((reg_index_cnt != 0 & ~reg_arb) | reg_arb)
								reg_data_cnt <= reg_data_cnt + 1;
                            end
                        end
            ST_DATA  :  begin
                            reg_rd <= ~reg_arb & reg_clk_cnt > wire_div_num[2:1];
                            reg_wr <= reg_arb & reg_clk_cnt <= wire_div_num[2:1] & (~wire_st_chg);
                            reg_data <= reg_arb ? wire_ram_rd_data : 0;
                            reg_dly_cnt <= 0;
                            if(reg_clk_cnt >= wire_div_num)
                                reg_data_cnt <= reg_data_cnt + 1;
                        end
            ST_END   :  begin   
                            reg_cs <= 0;
                            reg_wr <= 0;
                            reg_rd <= 0;
                            if(reg_clk_cnt >= wire_div_num)
                                reg_dly_cnt <= reg_dly_cnt + 1;
                                
                                
                        end
        endcase
    end
end

assign wire_cs_n = ~reg_cs;
assign wire_wr_n = ~reg_wr;
assign wire_rd_n = ~reg_rd;
// assign wire_data_o = reg_data;
assign wire_data_o = (reg_cur_state == ST_INDEX | reg_cur_state == ST_DATA) ? (reg_arb ? wire_ram_rd_data : 0) : reg_data;
assign wire_addr = reg_addr;
assign wire_data_oe = (~wire_cs_n & (~wire_wr_n | reg_arb));

reg reg_wr_d1;
reg reg_rd_d1;
reg reg_rd_d2;
reg reg_cs_d1;
reg [7:0] reg_data_d1;

wire wire_rd_pos;
wire wire_cs_pos;
wire [7:0] wire_data_tmp;
always @(posedge wire_clk) begin
    reg_wr_d1 <= wire_wr_n;
    reg_rd_d1 <= wire_rd_n;
    reg_rd_d2 <= reg_rd_d1;
    reg_cs_d1 <= wire_cs_n;
    // reg_data_d1 <= wire_data_i;
end

always @(negedge reg_rd) begin
    reg_data_d1 <= wire_data_i;
end

// assign wire_data_tmp = wire_div_num == 1 ? wire_data_i : reg_data_d1;
assign wire_data_tmp = reg_data_d1;
//assign wire_data_tmp = wire_data_i;

// assign wire_rd_pos = wire_div_num == 0 ? ~wire_rd_n : wire_rd_n & ~reg_rd_d1;
assign wire_rd_pos = reg_rd_d1 & ~reg_rd_d2;
// assign wire_rd_pos = wire_div_num == 1 ? reg_rd_d1 & ~reg_rd_d2 : wire_rd_n & ~reg_rd_d1;
assign wire_cs_pos = wire_cs_n & ~reg_cs_d1;

//--

always @(posedge wire_clk or negedge wire_rstn) begin
    if(~wire_rstn)
        reg_arb <= 0;
    else if(wire_loop_en) begin
        if(reg_cur_state == ST_END & wire_st_chg)
           reg_arb <= ~reg_arb; 
    end
    else
        reg_arb <= 0;
end

always @(posedge wire_clk or negedge wire_rstn) begin
    if(~wire_rstn)
        reg_burst_cnt <= 0;
    else if(reg_cur_state == ST_END & wire_st_chg & reg_arb) begin
        if(reg_burst_cnt >= reg_burst_num - 1)
            reg_burst_cnt <= 0;
        else
            reg_burst_cnt <= reg_burst_cnt + 1;
    end
end

reg [11:0] reg_ram_wr_cnt;
always @(posedge wire_clk or negedge wire_rstn) begin
    if(~wire_rstn)
        reg_ram_wr_cnt <= 0;
    else begin
        if(reg_arb)
            reg_ram_wr_cnt <= 0;
        else if(wire_ram_wr_en)
            reg_ram_wr_cnt <= reg_ram_wr_cnt + 1;
    end
end
        

//ram_4096 m_ram_4096 (
//  .wr_data  (wire_data_tmp      ), // input [7:0]
//  .addr     (wire_ram_addr      ), // input [11:0]
//  .wr_en    (wire_ram_wr_en     ), // input
//  .clk      (wire_clk           ), // input
//  .rst      (~wire_rstn         ), // input
//  .rd_data  (wire_ram_rd_data   )  // output [7:0]
//);
assign wire_ram_wr_data = wire_data_tmp;
assign wire_ram_addr = reg_arb ? reg_data_cnt : reg_ram_wr_cnt;
// assign wire_ram_addr = reg_data_cnt;
assign wire_ram_wr_en = ~reg_arb & wire_rd_pos & wire_loop_en;



endmodule