module s_axi_mem #(
  parameter SLAVE_BASE_ADDR = 32'h40000000,
  parameter SLAVE_ADDR_MASK = 32'hF0000000,
  parameter ID_WIDTH = 1,
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32,
  parameter AWUSER_WIDTH = 0,
  parameter ARUSER_WIDTH = 0,
  parameter WUSER_WIDTH = 0,
  parameter RUSER_WIDTH = 0,
  parameter BUSER_WIDTH = 0
) (
  output logic                    mem_read,
  output logic                    mem_write,
  output logic [ADDR_WIDTH-1:0]   mem_address,
  output logic [DATA_WIDTH-1:0]   mem_write_data,
  output logic [DATA_WIDTH/8-1:0] mem_write_strb,
  input  logic [DATA_WIDTH-1:0]   mem_read_data,
  input  logic                    s_axi_aclk,
  input  logic                    s_axi_aresetn,
  input  logic [ID_WIDTH-1:0]     s_axi_awid,
  input  logic [ADDR_WIDTH-1:0]   s_axi_awaddr,
  input  logic [7:0]              s_axi_awlen,
  input  logic [2:0]              s_axi_awsize,
  input  logic [1:0]              s_axi_awburst,
  input  logic                    s_axi_awlock,
  input  logic [3:0]              s_axi_awcache,
  input  logic [2:0]              s_axi_awport,
  input  logic [3:0]              s_axi_awqos,
  input  logic [AWUSER_WIDTH-1:0] s_axi_awuser,
  input  logic                    s_axi_awvalid,
  output logic                    s_axi_awready,
  input  logic [DATA_WIDTH-1:0]   s_axi_wdata,
  input  logic [DATA_WIDTH/8-1:0] s_axi_wstrb,
  input  logic                    s_axi_wlast,
  input  logic [WUSER_WIDTH-1:0]  s_axi_wuser,
  input  logic                    s_axi_wvalid,
  output logic                    s_axi_wready,
  output logic [ID_WIDTH-1:0]     s_axi_bid,
  output logic [1:0]              s_axi_bresp,
  output logic [BUSER_WIDTH-1:0]  s_axi_buser,
  output logic                    s_axi_wvalid,
  input  logic                    s_axi_wready,
  input  logic [ID_WIDTH-1:0]     s_axi_arid,
  input  logic [ADDR_WIDTH-1:0]   s_axi_araddr,
  input  logic [7:0]              s_axi_arlen,
  input  logic [2:0]              s_axi_arsize,
  input  logic [1:0]              s_axi_arburst,
  input  logic                    s_axi_arlock,
  input  logic [3:0]              s_axi_arcache,
  input  logic [2:0]              s_axi_arport,
  input  logic [3:0]              s_axi_arqos,
  input  logic [ARUSER_WIDTH-1:0] s_axi_aruser,
  input  logic                    s_axi_arvalid,
  output logic                    s_axi_arready,
  output logic [ID_WIDTH-1:0]     s_axi_rid,
  output logic [DATA_WIDTH-1:0]   s_axi_rdata,
  output logic [1:0]              s_axi_rresp,
  output logic [RUSER_WIDTH-1:0]  s_axi_ruser,
  output logic                    s_axi_rvalid,
  input  logic                    s_axi_rready
);
  
  logic s_axi_areset;
  assign s_axi_areset = ~s_axi_aresetn;
  
  logic [ADDR_WIDTH-1:0]  axi_awaddr;
  logic                   axi_awaddr_invalid;
  logic                   axi_awready;
  logic                   axi_wready;
  logic [1:0]             axi_bresp;
  logic [BUSER_WIDTH-1:0] axi_buser = 0;
  logic                   axi_bvalid;
  logic [ADDR_WIDTH-1:0]  axi_araddr;
  logic                   axi_araddr_invalid;
  logic                   axi_arready;
  logic [DATA_WIDTH-1:0]  axi_rdata;
  logic [1:0]             axi_rresp;
  logic                   axi_rlast;
  logic [RUSER_WIDTH-1:0] axi_ruser = 0;
  logic                   axi_rvalid;
  logic                   aw_wrap_en;
  logic                   ar_wrap_en;
  logic [31:0]            aw_wrap_size;
  logic [31:0]            ar_wrap_size;
  logic [7:0]             axi_awlen_cntr;
  logic [7:0]             axi_arlen_cntr;
  logic [1:0]             axi_awburst;
  logic [1:0]             axi_arburst;
  logic [7:0]             axi_awlen;
  logic [7:0]             axi_arlen;
  
  localparam ADDR_LSB = $clog2(DATA_WIDTH/8);
  
  assign s_axi_awready = axi_awready;
  assign s_axi_wready  = axi_wready;
  assign s_axi_bresp   = axi_bresp;
  assign s_axi_buser   = axi_buser;
  assign s_axi_bvalid  = axi_bvalid;
  assign s_axi_arready = axi_arready;
  assign s_axi_rdata   = axi_rdata;
  assign s_axi_rresp   = axi_rresp;
  assign s_axi_ruser   = axi_ruser;
  
  assign s_axi_bid     = s_axi_awid;
  assign s_axi_rid     = s_axi_arid;
  
  assign aw_wrap_size = axi_awlen << $clog2(DATA_WIDTH/8);
  assign ar_wrap_size = axi_arlen << $clog2(DATA_WIDTH/8);
  assign aw_wrap_en   = (axi_awaddr & aw_wrap_size) == aw_wrap_size ? 1'b1 : 1'b0;
  assign ar_wrap_en   = (axi_araddr & ar_wrap_size) == ar_wrap_size ? 1'b1 : 1'b0;
  
  always_ff @(posedge s_axi_aclk) begin
    if (s_axi_areset) begin
      s_axi_rvalid <= 1'b0;
      s_axi_rlast <= 1'b0;
    end else begin
      s_axi_rvalid <= axi_rvalid;
      s_axi_rlast <= axi_rlast;
    end
  end
  
  typedef enum {IDLE,WR_ACTIVE,WR_RESP,RD_ACTIVE,RD_DONE} state_type;
  // accept either rd/wr at a atime, supports only Single-Port-RAM
  always_ff @(posedge s_axi_aclk) begin
    if (s_axi_areset) begin
      state <= IDLE;
    end else begin
      case (state)
        IDLE : begin
          if (~axi_awready && s_axi_awvalid) begin
            state <= WR_ACTIVE;
          end else if (~axi_arready && s_axi_arvalid) begin
            state <= RD_ACTIVE;
          end
        end
        WR_ACTIVE : begin
          if (s_axi_wlast && s_axi_wvalid && axi_wready) begin
            state <= WR_RESP;
          end
        end
        WR_RESP : begin
          if (s_axi_bready && axi_bvalid) begin
            state <= IDLE;
          end
        end
        RD_ACTIVE : begin
          if (axi_rvalid && s_axi_rready && axi_arlen_cntr == axi_arlen) begin
            state <= RD_DONE;
          end
        end
        RD_DONE : begin
          state <= IDLE;
        end
        default : state <= IDLE;
      endcase
    end
  end
  
  always_ff @(posedge s_axi_aclk) begin
    if (s_axi_areset) begin
      axi_awready <= 1'b0;
      axi_arready <= 1'b0;
    end else if (~axi_awready && s_axi_awvalid && state == IDLE) begin
      axi_awready <= 1'b1;
    end else if (~axi_arready && s_axi_arvalid && state == IDLE) begin
      axi_arready <= 1'b1;
    end else begin
      axi_awready <= 1'b0;
      axi_arready <= 1'b0;
    end
  end
  
  always_ff @(posedge s_axi_aclk) begin
    if (s_axi_areset || (axi_awready && s_axi_awvalid)) begin
      axi_wready <= 1'b0;
    end else if (~axi_wready && s_axi_wvalid && state == WR_ACTIVE) begin
      axi_wready <= 1'b1;
    end else if (s_axi_wlast && s_axi_wvalid && axi_wready) begin
      axi_wready <= 1'b0;
    end
  end
  
  always_ff @(posedge s_axi_aclk) begin
    if (s_axi_areset || (axi_awready && s_axi_awvalid)) begin
      axi_bvalid <= 1'b0;
      axi_bresp <= 2'b00;
    end else if (s_axi_wlast && s_axi_wvalid && axi_wready) begin
      axi_bvalid <= 1'b1;
      axi_bresp <= {axi_awaddr_invalid,1'b0}; // 2'b00 - OKAY Resp
    end else if (s_axi_bready && axi_bvalid) begin
      axi_bvalid <= 1'b0;
    end
  end
  
  always_ff @(posedge s_axi_aclk) begin
    if (s_axi_areset || (axi_arready && s_axi_arvalid)) begin
      axi_rvalid <= 1'b0;
      axi_rresp <= 2'b00;
    end else if (~axi_rvalid && state == RD_ACTIVE) begin
      axi_rvalid <= 1'b1;
      axi_rresp <= {axi_araddr_invalid,1'b0}; // 2'b00 - OKAY Resp
    end else if (axi_rlast && axi_rvalid && s_axi_rready) begin
      axi_rvalid <= 1'b0;
    end
  end
  
  always_ff @(posedge s_axi_aclk) begin
    if (s_axi_areset || (axi_arready && s_axi_arvalid)) begin
      axi_rlast <= 1'b0;
    end else if (~axi_rlast && (axi_arlen_cntr == axi_arlen-1) && state == RD_ACTIVE) begin
      axi_rlast <= 1'b1;
    end else if (axi_rlast && axi_rvalid && s_axi_rready) begin
      axi_rlast <= 1'b0;
    end
  end
  
  always_ff @(posedge s_axi_aclk) begin
    if (s_axi_areset || state == IDLE) begin
      axi_awaddr_invalid <= 1'b0;
    end else if (axi_awready && s_axi_awvalid) begin
      axi_awaddr_invalid <= (s_axi_awaddr & SLAVE_ADDR_MASK) != (SLAVE_BASE_ADDR & SLAVE_ADDR_MASK);
    end
  end
  
  always_ff @(posedge s_axi_aclk) begin
    if (s_axi_areset) begin
      axi_awaddr <= 0;
      axi_awlen_cntr <= 0;
      axi_awburst <= 0;
      axi_awlen <= 0;
    end else if (axi_awready && s_axi_awvalid) begin
      axi_awaddr <= s_axi_awaddr[ADDR_WIDTH-1:0];
      axi_awlen_cntr <= 0;
      axi_awburst <= s_axi_awburst;
      axi_awlen <= s_axi_awlen;
    end else if ((axi_awlen_cntr <= axi_awlen) && axi_wready && s_axi_wvalid) begin
      axi_awlen_cntr <= axi_awlen_cntr + 1;
      case(axi_awburst)
        2'b00 : begin
          axi_awaddr <= axi_awaddr;
        end
        2'b01 : begin
          axi_awaddr[ADDR_WIDTH-1:ADDR_LSB] <= axi_awaddr[ADDR_WIDTH-1:ADDR_LSB] + 1;
          axi_awaddr[ADDR_LSB-1:0] <= {ADDR_LSB{1'b0}};
        end
        2'b10 : begin
          if (aw_wrap_en) begin
            axi_awaddr <= (axi_awaddr - aw_wrap_size);
          end else begin
            axi_awaddr[ADDR_WIDTH-1:ADDR_LSB] <= axi_awaddr[ADDR_WIDTH-1:ADDR_LSB] + 1;
            axi_awaddr[ADDR_LSB-1:0] <= {ADDR_LSB{1'b0}};
          end
        end
        default : begin
          axi_awaddr[ADDR_WIDTH-1:ADDR_LSB] <= axi_awaddr[ADDR_WIDTH-1:ADDR_LSB] + 1;
        end
      endcase
    end
  end
  
  always_ff @(posedge s_axi_aclk) begin
    if (s_axi_areset || state == IDLE) begin
      axi_araddr_invalid <= 1'b0;
    end else if (axi_arready && s_axi_arvalid) begin
      axi_araddr_invalid <= (s_axi_araddr & SLAVE_ADDR_MASK) != (SLAVE_BASE_ADDR & SLAVE_ADDR_MASK);
    end
  end
  
  always_ff @(posedge s_axi_aclk) begin
    if (s_axi_areset) begin
      axi_araddr <= 0;
      axi_arlen_cntr <= 0;
      axi_arburst <= 0;
      axi_arlen <= 0;
    end else if (axi_arready && s_axi_arvalid) begin
      axi_araddr <= s_axi_araddr[ADDR_WIDTH-1:0];
      axi_arlen_cntr <= 0;
      axi_arburst <= s_axi_arburst;
      axi_arlen <= s_axi_arlen;
    end else if ((axi_arlen_cntr <= axi_arlen) && axi_rvalid && s_axi_rready) begin
      axi_arlen_cntr <= axi_arlen_cntr + 1;
      case(axi_arburst)
        2'b00 : begin
          axi_araddr <= axi_araddr;
        end
        2'b01 : begin
          axi_araddr[ADDR_WIDTH-1:ADDR_LSB] <= axi_araddr[ADDR_WIDTH-1:ADDR_LSB] + 1;
          axi_araddr[ADDR_LSB-1:0] <= {ADDR_LSB{1'b0}};
        end
        2'b10 : begin
          if (ar_wrap_en) begin
            axi_araddr <= (axi_araddr - ar_wrap_size);
          end else begin
            axi_araddr[ADDR_WIDTH-1:ADDR_LSB] <= axi_araddr[ADDR_WIDTH-1:ADDR_LSB] + 1;
            axi_araddr[ADDR_LSB-1:0] <= {ADDR_LSB{1'b0}};
          end
        end
        default : begin
          axi_araddr[ADDR_WIDTH-1:ADDR_LSB] <= axi_araddr[ADDR_WIDTH-1:ADDR_LSB] + 1;
        end
      endcase
    end
  end
  
  assign mem_read = state == RD_ACTIVE && ~axi_araddr_invalid;
  assign mem_write = axi_wready && s_axi_wvalid && ~axi_awaddr_invalid;
  assign mem_address = state == WR_ACTIVE ? axi_awaddr : axi_araddr;
  assign mem_write_strb = s_axi_wstrb;
  assign mem_write_data = s_axi_wdata;
  assign axi_rdata = mem_read_data;
  
endmodule
