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
  
endmodule
