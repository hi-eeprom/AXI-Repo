module s_axis_mem #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 5
) (
  input  logic s_axis_aclk,
  input  logic s_axis_aresetn,
  input  logic s_axis_tvalid,
  input  logic [DATA_WIDTH-1:0] s_axis_tdata,
  input  logic [DATA_WIDTH/8-1:0] s_axis_tstrb,
  input  logic s_axis_tlast,
  output logic s_axis_tready,
  output logic rx_start,
  output logic [ADDR_WIDTH-1:0] rx_count,
  output logic rx_done,
  output logic [DATA_WIDTH/8-1:0] mem_write_be,
  output logic [ADDR_WIDTH-1:0] mem_write_address,
  output logic [DATA_WIDTH-1:0] mem_write_data
);

endmodule
