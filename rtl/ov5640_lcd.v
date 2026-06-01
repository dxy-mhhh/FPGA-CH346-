
module ov5640_lcd(    
    input         sys_clk    ,  
    input         sys_rst_n  ,  

    input         cam_pclk   ,  
    input         cam_vsync  ,  
    input         cam_href   ,  
    input  [7:0]  cam_data   ,  
    output        cam_rst_n  ,  
    output        cam_pwdn   ,  
    output        cam_scl    ,  
    inout         cam_sda    ,  
    //SDRAM 
    output        sdram_clk  ,  
    output        sdram_cke  ,  
    output        sdram_cs_n ,  
    output        sdram_ras_n,  
    output        sdram_cas_n,  
    output        sdram_we_n ,  
    output [1:0]  sdram_ba   ,  
    output [1:0]  sdram_dqm  ,  
    output [12:0] sdram_addr ,  
    inout  [15:0] sdram_data ,  
    //LCD                    
    output        lcd_hs     ,  
    output        lcd_vs     ,  
    output        lcd_de     ,  
    inout  [23:0] lcd_rgb    ,  
    output        lcd_bl     ,  
    output        lcd_rst    ,  
    output        lcd_pclk   ,  
    //CH346
    input           rdne_n    , 
    input           wrnf_n    , 
    output          cs_n      , 
    output          wr_n      , 
    output          rd_n      , 
    output          addr      , 
    inout   [7:0]   data        
    );

//parameter define
parameter SLAVE_ADDR = 7'h3c          ; 
parameter BIT_CTRL   = 1'b1           ; 
parameter CLK_FREQ   = 27'd100_000_000; 
parameter I2C_FREQ   = 18'd250_000    ; 

//wire define
wire        clk_100m       ;  //
wire        clk_100m_shift ;  //
wire        clk_100m_lcd   ;  //
wire        clk_lcd        ;  
wire        locked         ;
wire        rst_n          ;
wire        sys_init_done  ;  //

wire        i2c_exec       ;  //
wire [23:0] i2c_data       ;  //
wire        i2c_done       ;  //
wire        i2c_dri_clk    ;  //
wire [ 7:0] i2c_data_r     ;  //
wire        i2c_rh_wl      ;  //
wire        cam_init_done  ;  //
                           
wire        wr_en          ;  //
wire [15:0] wr_data        ;  //
wire        rd_en          ;  //
wire [15:0] rd_data        ;  //
wire        sdram_init_done;  //
wire        bank_wr_ready  ;  //

wire        sdram_rd_en_ctrl;
wire [9:0]  sdram_rd_usedw;
wire        to8_wr_en_ctrl;
wire [15:0] to8_wr_data_ctrl;

wire [15:0] ID_lcd         ; 
wire [7:0]  ch346_ext_data;  
wire        wire_send_data_sent;
wire        to8_wrfull;         
wire        to8_rdempty;        
wire        to8_rdreq;          
wire [12:0] to8_wrusedw;        
wire        to8_write_less_than_20pct; 
wire        to8_write_full_70pct;      

reg  [15:0] test_data;          
reg         test_wr_en;         
reg  [15:0] wr_cnt;             
wire [12:0] cmos_h_pixel   ;  
wire [12:0] cmos_v_pixel   ;  
wire [12:0] total_h_pixel  ; 
wire [12:0] total_v_pixel  ; 
wire [23:0] sdram_max_addr ;  


reg [1:0]   spd_sel   ;  
reg         loop_en   ;  
wire [3:0]  led       ;  

//*****************************************************
//**                    main code
//*****************************************************

always @(posedge clk_50m or negedge rst_n) begin
    if(~rst_n) begin
        test_data <= 16'd0;
        test_wr_en <= 1'b0;
        wr_cnt <= 16'd0;
    end
    else if(~to8_wrfull) begin
        test_wr_en <= 1'b1;
        test_data <= test_data + 16'd1;
        wr_cnt <= wr_cnt + 16'd1;
    end
    else begin
        test_wr_en <= 1'b0;
    end
end

always @(posedge clk_100m or negedge rst_n) begin
    if(~rst_n) begin
        spd_sel <= 2'd1;  
        loop_en <= 1'b0;  
    end
    else begin
        spd_sel <= 2'd1;  
        loop_en <= 1'b0;  
    end
end

assign  rst_n = sys_rst_n & locked;

assign  sys_init_done = sdram_init_done & cam_init_done;
assign  cam_pwdn  = 1'b0;
assign  cam_rst_n = 1'b1;


pll u_pll(
    .areset             (~sys_rst_n),
    .inclk0             (sys_clk),
            
    .c0                 (clk_100m),
    .c1                 (clk_100m_shift),
    .c2                 (clk_100m_lcd),
	 .c3                 (clk_50m),
    .locked             (locked)
    );

lcd u_lcd(
    .clk                (clk_100m_lcd),
    .rst_n              (rst_n),
                        
    .lcd_hs             (lcd_hs),
    .lcd_vs             (lcd_vs),
    .lcd_de             (lcd_de),
    .lcd_rgb            (lcd_rgb),
    .lcd_bl             (lcd_bl),
    .lcd_rst            (lcd_rst),
    .lcd_pclk           (lcd_pclk),
            
    .pixel_data         (rd_data),
    .rd_en              (rd_en),
    .clk_lcd            (clk_lcd),          //LCD濠电姷鏁告慨鐑姐€傞鐐潟闁哄洢鍨圭壕濠氭煟閺冨倸甯剁紒鐘靛█閺岀喖骞嗚閿涘秹鏌￠崱顓㈡闁靛洤瀚伴獮鎺戭吋閸パ冾瀴闂備礁鎲￠悷銉ф崲濮椻偓瀵顓兼径濠佺炊闂佸憡娲﹂崜娆忊枍閿濆洨纾藉〒姘搐娴滄粎绱掓径濠勭Ш鐎殿喛顕ч埥澶愬閳哄倹娅囬梻浣瑰缁诲倸螞濞戔懞鍥Ω閳哄倻鍘

    .ID_lcd             (ID_lcd)            //LCD ID
    );
    
picture_size u_picture_size (
    .rst_n              (rst_n),

    .ID_lcd             (16'd1),           
                        
    .cmos_h_pixel       (cmos_h_pixel  ),  
    .cmos_v_pixel       (cmos_v_pixel  ),  
    .total_h_pixel      (total_h_pixel ),  
    .total_v_pixel      (total_v_pixel ),  
    .sdram_max_addr     (sdram_max_addr)   
    );
    
i2c_ov5640_rgb565_cfg u_i2c_cfg(
    .clk                (i2c_dri_clk),
    .rst_n              (rst_n),
            
    .i2c_exec           (i2c_exec),
    .i2c_data           (i2c_data),
    .i2c_rh_wl          (i2c_rh_wl),     
    .i2c_done           (i2c_done), 
    .i2c_data_r         (i2c_data_r),   
                
    .cmos_h_pixel       (cmos_h_pixel),  
    .cmos_v_pixel       (cmos_v_pixel) , 
    .total_h_pixel      (total_h_pixel), 
    .total_v_pixel      (total_v_pixel), 
        
    .init_done          (cam_init_done) 
    );    

i2c_dri #(
    .SLAVE_ADDR         (SLAVE_ADDR),       
    .CLK_FREQ           (CLK_FREQ  ),       
    .I2C_FREQ           (I2C_FREQ  ) 
    )
u_i2c_dr(
    .clk                (clk_100m_lcd),
    .rst_n              (rst_n     ),

    .i2c_exec           (i2c_exec  ),   
    .bit_ctrl           (BIT_CTRL  ),   
    .i2c_rh_wl          (i2c_rh_wl),        
    .i2c_addr           (i2c_data[23:8]),  
    .i2c_data_w         (i2c_data[7:0]),   
    .i2c_data_r         (i2c_data_r),   
    .i2c_done           (i2c_done  ),
    
    .scl                (cam_scl   ),   
    .sda                (cam_sda   ),   

    .dri_clk            (i2c_dri_clk)       
    );

cmos_capture_data u_cmos_capture_data(      
    .rst_n              (rst_n & sys_init_done),
    
    .cam_pclk           (cam_pclk),
    .cam_vsync          (cam_vsync),
    .cam_href           (cam_href),
    .cam_data           (cam_data),
    
    .bank_wr_ready      (bank_wr_ready),    //
    
    .cmos_frame_vsync   (),
    .cmos_frame_href    (),
    .cmos_frame_valid   (wr_en),            
    .cmos_frame_data    (wr_data)           
    );


sdram_top u_sdram_top(
    .ref_clk            (clk_100m),        
    .out_clk            (clk_100m_shift),  
    .rst_n              (rst_n),           
                                        
    .wr_clk             (cam_pclk),        
    .wr_en              (wr_en),           
    .wr_data            (wr_data),         
    .wr_min_addr        (24'd0),           
    .wr_max_addr        (sdram_max_addr),  
    .wr_len             (10'd512),         
    .wr_load            (~rst_n),          
                                                                        
    .rd_clk             (clk_lcd),          
    .rd_en              (rd_en),            
    .rd_data            (rd_data),          
    .rd_min_addr        (24'd0),            
    .rd_max_addr        (sdram_max_addr),   
    .rd_len             (10'd512),          
    .rd_load            (~rst_n),        
                                            
    .sdram_read_valid   (1'b1),             
    .sdram_pingpang_en  (1'b1),             
    .sdram_init_done    (sdram_init_done),  
    .bank_wr_ready      (bank_wr_ready),
    .rd_usedw           (sdram_rd_usedw),    
                                        
    .sdram_clk          (sdram_clk),        
    .sdram_cke          (sdram_cke),        
    .sdram_cs_n         (sdram_cs_n),       
    .sdram_ras_n        (sdram_ras_n),      
    .sdram_cas_n        (sdram_cas_n),      
    .sdram_we_n         (sdram_we_n),       
    .sdram_ba           (sdram_ba),         
    .sdram_addr         (sdram_addr),       
    .sdram_data         (sdram_data),       
    .sdram_dqm          (sdram_dqm)         
    );
	 
to8 u_to8(
    .wrclk      (clk_lcd),         
    .rdclk      (clk_100m),         
    .wrreq      (to8_wr_en_ctrl),       
    .rdreq      (to8_rdreq),        
    .data       (to8_wr_data_ctrl),        
    .q          (ch346_ext_data),   
    .wrfull     (to8_wrfull),       
	 .wrusedw     (to8_wrusedw),
	 .rdusedw     (),
    .rdempty    (to8_rdempty)       
);

sdram_to8_flow_ctrl u_sdram_to8_flow_ctrl(
    .clk_100m           (clk_lcd),
    .rst_n              (rst_n),
    
    .to8_wrfull         (to8_wrfull),
    .to8_rdempty        (to8_rdempty),
    .to8_wrusedw        (to8_wrusedw),
    .sdram_rd_en        (sdram_rd_en_ctrl),
    
    .sdram_rd_usedw     (sdram_rd_usedw),
    .sdram_rd_data      (rd_data),
    .to8_wr_en          (to8_wr_en_ctrl),
    .to8_wr_data        (to8_wr_data_ctrl)
);

assign to8_rdreq = wire_send_data_sent & ~to8_rdempty;

assign to8_write_less_than_20pct = (to8_wrusedw < 13'd2000); // 
assign to8_write_full_70pct      = (to8_wrusedw >= 13'd5500); // 


top u_ch346_top(
    .sys_clk            (clk_100m),         
    .rst_n              (rst_n),            

    //-- config
    .spd_sel            (spd_sel),          
    .loop_en            (loop_en),          
	 .ext_data			(ch346_ext_data),
    //-- flow control
    .rdne_n             (rdne_n),           // rd not empty
    .wrnf_n             (wrnf_n),           // wr not full, priority: wrnf > rdne

    //-- slave parallel interface
    .cs_n               (cs_n),             // 
    .wr_n               (wr_n),             //
    .rd_n               (rd_n),             //
    .addr               (addr),             // 
    .data               (data),             // 

    .led                (led),              
    .wire_send_data_sent(wire_send_data_sent) 
    );

endmodule 