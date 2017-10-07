module s_axi_interrupt #(
  parameter integer DATA_WIDTH = 32,
  parameter integer ADDR_WIDTH = 5,
  parameter integer NUM_OF_INTR = 1
) (
  input  logic                    s_axi_aclk,
  input  logic                    s_axi_aresetn,
  input  logic [ADDR_WIDTH-1:0]   s_axi_awaddr,
  input  logic [2:0]              s_axi_awport,
  input  logic                    s_axi_awvalid,
  output logic                    s_axi_awready,
  input  logic [DATA_WIDTH-1:0]   s_axi_wdata,
  input  logic [DATA_WIDTH/8-1:0] s_axi_wstrb,
  input  logic                    s_axi_wvalid,
  output logic                    s_axi_wready,
  output logic [1:0]              s_axi_bresp,
  output logic                    s_axi_bvalid,
  input  logic                    s_axi_bready,
  input  logic [ADDR_WIDTH-1:0]   s_axi_araddr,
  input  logic [2:0]              s_axi_arport,
  input  logic                    s_axi_arvalid,
  output logic                    s_axi_arready,
  output logic [DATA_WIDTH-1:0]   s_axi_rdata,
  output logic [1:0]              s_axi_rresp,
  output logic                    s_axi_rvalid,
  input  logic                    s_axi_rready,
  input  logic [NUM_OF_INTR-1:0]  ext_interrupt
);
  
  logic s_axi_areset;
  
  // AXI4Lite-signals
  logic [ADDR_WIDTH-1:0]  axi_awaddr;
  logic                   axi_awready;
  logic                   axi_wready;
  logic [1:0]             axi_bresp;
  logic                   axi_bvalid;
  logic [ADDR_WIDTH-1:0]  axi_araddr;
  logic                   axi_arready;
  logic [DATA_WIDTH-1:0]  axi_rdata;
  logic [1:0]             axi_rresp;
  logic                   axi_rvalid;
  // Interrupt register space
  logic                   intr_global_en;
  logic [NUM_OF_INTR-1:0] intr_en;
  logic [NUM_OF_INTR-1:0] intr_sts;
  logic [NUM_OF_INTR-1:0] intr_ack;
  logic [NUM_OF_INTR-1:0] intr_pending;
  
  logic intr_reg_ren;
  logic intr_reg_wen;
  
  assign s_axi_areset = ~s_axi_aresetn;
  assign s_axi_awready = axi_awready;
  assign s_axi_wready  = axi_wready;
  assign s_axi_bresp   = axi_bresp;
  assign s_axi_bvalid  = axi_bvalid;
  assign s_axi_arready = axi_arready;
  assign s_axi_rdata   = axi_rdata;
  assign s_axi_rresp   = axi_rresp;
  assign s_axi_rvalid  = axi_rvalid;
  
  always_ff @(posedge s_axi_aclk) begin
    if (s_axi_areset) begin
      axi_awready <= 1'b0;
      axi_awaddr <= {ADDR_WIDTH{1'b0}};
    end else if (~axi_awready && s_axi_awvalid && s_axi_wvalid) begin
      axi_awready <= 1'b1;
      axi_awaddr <= s_axi_awaddr;
    end else begin
      axi_awready <= 1'b0;
    end
  end
  
  always_ff @(posedge s_axi_aclk) begin
    if (s_axi_areset) begin
      axi_wready <= 1'b0;
    end else if (~axi_wready && s_axi_awvalid && s_axi_wvalid) begin
      axi_wready <= 1'b1;
    end else begin
      axi_wready <= 1'b0;
    end
  end
  
  assign intr_reg_wen = axi_wready & s_axi_wvalid & axi_awready & s_axi_awvalid;
  
  always_ff @(posedge s_axi_aclk) begin
    if (s_axi_areset) begin
      axi_bvalid <= 1'b0;
      axi_bresp <= 2'b00;
    end else if (~axi_bvalid && axi_awready && s_axi_awvalid && axi_wready && s_axi_wvalid) begin
      axi_bvalid <= 1'b1;
      axi_bresp <= 2'b00; // OKAY responce
    end else if (s_axi_bready && axi_bvalid) begin
      axi_bvalid <= 1'b0;
    end
  end
  
  always_ff @(posedge s_axi_aclk) begin
    if (s_axi_areset) begin
      axi_arready <= 1'b0;
      axi_araddr <= {ADDR_WIDTH{1'b0}};
    end else if (~axi_arready && s_axi_arvalid) begin
      axi_arready <= 1'b1;
      axi_araddr <= s_axi_araddr;
    end else begin
      axi_arready <= 1'b0;
    end
  end
  
  always_ff @(posedge s_axi_aclk) begin
    if (s_axi_areset) begin
      axi_rvalid <= 1'b0;
      axi_rresp <= 2'b00;
    end else if (~axi_rvalid && axi_arready && s_axi_arvalid) begin
      axi_rvalid <= 1'b1;
      axi_rresp <= 2'b00; // OKAY responce
    end else if (axi_rvalid && s_axi_rready) begin
      axi_rvalid <= 1'b0;
    end
  end
  
  assign intr_reg_ren = axi_arready & s_axi_arvalid & ~axi_rvalid;
  
  // Innterrupt register write
  // Global interrupt register
  always_ff @(posedge s_axi_aclk) begin
    if (s_axi_areset) begin
      intr_global_en <= 1'b0;
    end else if (intr_reg_wen && axi_awaddr[4:2] == 3'h0) begin
      intr_global_en <= s_axi_wdata[0];
    end
  end
  // interrupt enable register
  always_ff @(posedge s_axi_aclk) begin
    if (s_axi_areset) begin
      intr_en <= {NUM_OF_INTR{1'b0}};
    end else if (intr_reg_wen && axi_awaddr[4:2] == 3'h1) begin
      intr_en <= s_axi_wdata[NUM_OF_INTR-1:0];
    end
  end
  genvar i;
  generate for (i=0; i<NUM_OF_INTR; i++) begin : gen_intr_reg
    // interrupt status register
    always_ff @(posedge s_axi_aclk) begin
      if (s_axi_areset || intr_ack[i]) begin
        intr_sts[i] <= 1'b0;
      end else begin
        intr_sts[i] <= ext_interrupt[i];
      end
    end
    // interrupt acknowledgement register
    always_ff @(posedge s_axi_aclk) begin
      if (s_axi_areset || intr_ack[i]) begin
        intr_ack[i] <= 1'b0;
      end else if (intr_reg_wen && axi_awaddr[4:2] == 3'h3) begin
        intr_ack[i] <= s_axi_wdata[i];
      end
    end
    // interrupt pending register
    always_ff @(posedge s_axi_aclk) begin
      if (s_axi_areset || intr_ack[i]) begin
        intr_pending[i] <= 1'b0;
      end else begin
        intr_pending[i] <= intr_sts[i] & intr_en[i];
      end
    end
  end endgenerate
  // Innterrupt register read
  always_ff @(posedge s_axi_aclk) begin
    if (s_axi_areset) begin
      axi_rdata <= {DATA_WIDTH{1'b0}};
    end else if (intr_reg_ren) begin
      case (axi_araddr[4:2])
        3'h0    : axi_rdata <= intr_global_en;
        3'h1    : axi_rdata <= intr_en;
        3'h2    : axi_rdata <= intr_sts;
        3'h3    : axi_rdata <= intr_ack;
        3'h4    : axi_rdata <= intr_pending;
        default : axi_rdata <= {DATA_WIDTH{1'b0}};
      endcase
    end
  end
  
endmodule
