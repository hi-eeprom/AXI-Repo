module m_axi_mem #(
  parameter SLAVE_BASE_ADDR = 32'h40000000,
  parameter BURST_LEN = 16,
  parameter ID_WIDTH = 1,
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32,
  parameter AWUSER_WIDTH = 0,
  parameter ARUSER_WIDTH = 0,
  parameter WUSER_WIDTH = 0,
  parameter RUSER_WIDTH = 0,
  parameter BUSER_WIDTH = 0
) (
  input  logic txn_start,
  output logic txn_done,
  output logic txn_error,
  
  input  logic                    m_axi_aclk,
  input  logic                    m_axi_aresetn,
  output logic [ID_WIDTH-1:0]     m_axi_awid,
  output logic [ADDR_WIDTH-1:0]   m_axi_awaddr,
  output logic [7:0]              m_axi_awlen,
  output logic [2:0]              m_axi_awsize,
  output logic [1:0]              m_axi_awburst,
  output logic                    m_axi_awlock,
  output logic [3:0]              m_axi_awcache,
  output logic [2:0]              m_axi_awport,
  output logic [3:0]              m_axi_awqos,
  output logic [AWUSER_WIDTH-1:0] m_axi_awuser,
  output logic                    m_axi_awvalid,
  input  logic                    m_axi_awready,
  output logic [DATA_WIDTH-1:0]   m_axi_wdata,
  output logic [DATA_WIDTH/8-1:0] m_axi_wstrb,
  output logic                    m_axi_wlast,
  output logic [WUSER_WIDTH-1:0]  m_axi_wuser,
  output logic                    m_axi_wvalid,
  input  logic                    m_axi_wready,
  input  logic [ID_WIDTH-1:0]     m_axi_bid,
  input  logic [1:0]              m_axi_bresp,
  input  logic [BUSER_WIDTH-1:0]  m_axi_buser,
  input  logic                    m_axi_wvalid,
  output logic                    m_axi_wready,
  output logic [ID_WIDTH-1:0]     m_axi_arid,
  output logic [ADDR_WIDTH-1:0]   m_axi_araddr,
  output logic [7:0]              m_axi_arlen,
  output logic [2:0]              m_axi_arsize,
  output logic [1:0]              m_axi_arburst,
  output logic                    m_axi_arlock,
  output logic [3:0]              m_axi_arcache,
  output logic [2:0]              m_axi_arport,
  output logic [3:0]              m_axi_arqos,
  output logic [ARUSER_WIDTH-1:0] m_axi_aruser,
  output logic                    m_axi_arvalid,
  input  logic                    m_axi_arready,
  input  logic [ID_WIDTH-1:0]     m_axi_rid,
  input  logic [DATA_WIDTH-1:0]   m_axi_rdata,
  input  logic [1:0]              m_axi_rresp,
  input  logic [RUSER_WIDTH-1:0]  m_axi_ruser,
  input  logic                    m_axi_rvalid,
  output logic                    m_axi_rready
);
  
  logic m_axi_areset;
  assign m_axi_areset = ~m_axi_aresetn;
  
  typedef enum {IDLE,ACTIVE,DONE} state_type;
  state_type state;
  
  localparam TRANSACTION_NUM = $clog2(BURST_LEN-1);
  localparam MASTER_LENGHT = 12; // 4K address boundary
  localparam NO_BURSTS_REQ = MASTER_LENGHT-$clog2((BURST_LEN*DATA_WIDTH)-1);
  
  logic [ADDR_WIDTH-1:0] axi_awaddr;
  logic                  axi_awvalid;
  logic [DATA_WIDTH-1:0] axi_wdata;
  logic                  axi_wlast;
  logic                  axi_wvalid;
  logic                  axi_bready;
  logic [ADDR_WIDTH-1:0] axi_araddr;
  logic                  axi_arvalid;
  logic                  axi_rready;
  
  logic [TRANSACTION_NUM:0] wr_index;
  logic [TRANSACTION_NUM:0] rd_index;
  logic [NO_BURSTS_REQ:0] wr_burst_counter;
  logic [NO_BURSTS_REQ:0] rd_burst_counter;
  
  logic start_wr_burst;
  logic start_rd_burst;
  logic wr_done;
  logic rd_done;
  logic wr_resp_error;
  logic rd_resp_error;
  
  assign m_axi_awid    = 'b0;
  assign m_axi_awaddr  = axi_awaddr;
  assign m_axi_awlen   = BURST_LEN-1;
  assign m_axi_awsize  = $clog2(DATA_WIDTH/8-1);
  assign m_axi_awburst = 2'b01;
  assign m_axi_awlock  = 1'b0;
  assign m_axi_awcache = 4'b0010;
  assign m_axi_awport  = 3'h0;
  assign m_axi_awqos   = 4'h0;
  assign m_axi_awuser  = 'b1;
  assign m_axi_awvalid = axi_awvalid;
  assign m_axi_wdata   = axi_wdata;
  assign m_axi_wstrb   = {DATA_WIDTH/8{1'b1}};
  assign m_axi_wlast   = axi_wlast;
  assign m_axi_wuser   = 'b0;
  assign m_axi_wvalid  = axi_wvalid;
  assign m_axi_bready  = axi_bready;
  assign m_axi_arid    = 'h0;
  assign m_axi_araddr  = axi_araddr;
  assign m_axi_arlen   = BURST_LEN-1;
  assign m_axi_arsize  = $clog2(DATA_WIDTH/8-1);
  assign m_axi_arburst = 2'b01;
  assign m_axi_arlock  = 1'b0;
  assign m_axi_arcache = 4'b0010;
  assign m_axi_arwport = 3'h0;
  assign m_axi_arqos   = 4'h0;
  assign m_axi_aruser  = 'b1;
  assign m_axi_arvalid = axi_arvalid;
  assign m_axi_rready  = axi_rready;
  
  assign txn_done = wr_done | rd_done;
  
  always_ff @(posedge m_axi_aclk) begin
    if (m_axi_areset || wr_state == IDLE) begin
      axi_awvalid <= 1'b0;
      axi_awaddr <= SLAVE_BASE_ADDR;
    end else if (~axi_awvalid && start_wr_burst) begin
      axi_awvalid <= 1'b1;
    end else if (axi_awvalid && m_axi_awready) begin
      axi_awvalid <= 1'b0;
      axi_awaddr <= axi_awaddr + (BURST_LEN*DATA_WIDTH/8);
    end
  end
  
  always_ff @(posedge m_axi_aclk) begin
    if (m_axi_areset || wr_state == IDLE) begin
      axi_wvalid <= 1'b0;
    end else if (~axi_wvalid && start_wr_burst) begin
      axi_wvalid <= 1'b1;
    end else if (axi_wvalid && axi_wlast && m_axi_wready) begin
      axi_wvalid <= 1'b0;
    end
  end
  
  always_ff @(posedge m_axi_aclk) begin
    if (m_axi_areset || wr_state == IDLE) begin
      axi_wlast <= 1'b0;
    end else if ((axi_wvalid && m_axi_wready && wr_index == BURST_LEN-2 && BURST_LEN >= 2) || BURST_LEN == 1) begin
      axi_wlast <= 1'b1;
    end else if (axi_wvalid && axi_wlast && m_axi_wready) begin
      axi_wlast <= 1'b0;
    end
  end
  
  always_ff @(posedge m_axi_aclk) begin
    if (m_axi_areset || start_wr_burst) begin
      wr_index <= 0;
    end else if (axi_wvalid && m_axi_wready) begin
      wr_index <= wr_index + 1;
    end
  end
  
  assign axi_wdata = wr_index;
  
  always_ff @(posedge m_axi_aclk) begin
    if (m_axi_areset || wr_state == IDLE) begin
      axi_bready <= 1'b0;
    end else if (~axi_bready && m_axi_bvalid) begin
      axi_bready <= 1'b1;
    end else if (axi_bready) begin
      axi_bready <= 1'b0;
    end
  end
  
  assign wr_resp_error = axi_bready & m_axi_bvalid & m_axi_bresp[1];
  
  always_ff @(posedge m_axi_aclk) begin
    if (m_axi_areset || rd_state == IDLE) begin
      axi_arvalid <= 1'b0;
      axi_araddr <= SLAVE_BASE_ADDR;
    end else if (~axi_arvalid && start_rd_burst) begin
      axi_arvalid <= 1'b1;
    end else if (axi_arvalid && m_axi_arready) begin
      axi_arvalid <= 1'b0;
      axi_araddr <= axi_araddr + (BURST_LEN*DATA_WIDTH/8);
    end
  end
  
  always_ff @(posedge m_axi_aclk) begin
    if (m_axi_areset || rd_state == IDLE) begin
      axi_rready <= 1'b0;
    end else if (~axi_rready && start_rd_burst) begin
      axi_rready <= 1'b1;
    end else if (m_axi_rvalid && m_axi_rlast && axi_rready) begin
      axi_rready <= 1'b0;
    end
  end
  
  always_ff @(posedge m_axi_aclk) begin
    if (m_axi_areset || start_rd_burst) begin
      rd_index <= 0;
    end else if (m_axi_rvalid && axi_rready) begin
      rd_index <= rd_index + 1;
    end
  end
  
  assign rd_resp_error = axi_rready & m_axi_rvalid & m_axi_rresp[1];
  
  always_ff @(posedge m_axi_aclk) begin
    if (m_axi_areset || start_wr_burst) begin
      wr_burst_counter <= 0;
    end else if (m_axi_awready && axi_awvalid && wr_burst_counter[NO_BURSTS_REQ]) begin
      wr_burst_counter <= wr_burst_counter;
    end else if (m_axi_awready && axi_awvalid) begin
      wr_burst_counter <= wr_burst_counter + 1;
    end
  end
  
  always_ff @(posedge m_axi_aclk) begin
    if (m_axi_areset || start_rd_burst) begin
      rd_burst_counter <= 0;
    end else if (m_axi_arready && axi_arvalid && rd_burst_counter[NO_BURSTS_REQ]) begin
      rd_burst_counter <= rd_burst_counter;
    end else if (m_axi_arready && axi_arvalid) begin
      rd_burst_counter <= rd_burst_counter + 1;
    end
  end
  
  always_ff @(posedge m_axi_aclk) begin
    if (m_axi_areset) begin
      wr_state <= IDLE;
      start_wr_burst <= 1'b0;
    end else begin
      case (wr_state)
        IDLE : begin
          if (txn_start) begin
            wr_state <= ACTIVE;
            start_wr_burst <= 1'b1;
          end
        end
        ACTIVE : begin
          if (m_axi_bvalid && axi_bready && wr_burst_counter[NO_BURSTS_REQ]) begin
            wr_state <= IDLE;
          end else if (m_axi_bvalid && axi_bready) begin
            wr_state <= DONE;
          end
          start_wr_burst <= 1'b0;
        end
        DONE : begin
          wr_state <= ACTIVE;
          start_wr_burst <= 1'b1;
        end
      endcase
    end
  end
  
  always_ff @(posedge m_axi_aclk) begin
    if (m_axi_areset) begin
      rd_state <= IDLE;
      start_rd_burst <= 1'b0;
    end else begin
      case (rd_state)
        IDLE : begin
          if (txn_start) begin
            rd_state <= ACTIVE;
            start_rd_burst <= 1'b1;
          end
        end
        ACTIVE : begin
          if (m_axi_rvalid && m_axi_rlast && axi_rready && rd_burst_counter[NO_BURSTS_REQ]) begin
            rd_state <= IDLE;
          end else if (m_axi_rvalid && m_axi_rlast && axi_rready) begin
            rd_state <= DONE;
          end
          start_rd_burst <= 1'b0;
        end
        DONE : begin
          rd_state <= ACTIVE;
          start_rd_burst <= 1'b1;
        end
      endcase
    end
  end
  
endmodule
