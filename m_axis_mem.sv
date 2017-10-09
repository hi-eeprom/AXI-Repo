module m_axis_mem #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 5
) (
  input  logic                    m_axis_aclk,
  input  logic                    m_axis_aresetn,
  output logic                    m_axis_tvalid,
  output logic [DATA_WIDTH-1:0]   m_axis_tdata,
  output logic [DATA_WIDTH/8-1:0] m_axis_tstrb,
  output logic                    m_axis_tlast,
  input  logic                    m_axis_tready,
  input  logic                    tx_start,
  input  logic [ADDR_WIDTH-1:0]   tx_count,
  output logic                    tx_done,
  output logic                    mem_read,
  output logic [ADDR_WIDTH-1:0]   mem_read_address,
  input  logic [DATA_WIDTH-1:0]   mem_read_data
);
  
  logic m_axis_areset;
  assign m_axis_areset = ~m_axis_aresetn;
  
  typedef enum {IDLE,ACTIVE} state_type;
  state_type state;
  
  logic [ADDR_WIDTH-1:0] read_pointer;
  logic axis_tvalid;
  logic axis_tlast;
  logic tx_en;
  
  assign m_axis_tdata = mem_read_data;
  assign m_axis_tstrb = {DATA_WIDTH/8{1'b1}};
  
  assign tx_en = m_axis_tvalid && m_axis_tready;
  
  assign axis_tvalid = state == ACTIVE && read_pointer <= tx_count;
  assign axis_tlast = read_pointer == tx_count;
  
  assign mem_read = axis_tvalid;
  assign mem_read_address = read_pointer;
  
  always_ff @(posedge m_axis_aclk) begin
    if (m_axis_areset) begin
      m_axis_tvalid <= 1'b0;
      m_axis_tlast <= 1'b0;
    end else begin
      m_axis_tvalid <= axis_tvalid;
      m_axis_tlast <= axis_tlast;
    end
  end
  
  always_ff @(posedge m_axis_aclk) begin
    if (m_axis_areset) begin
      tx_done <= 1'b0;
    end else begin
      tx_done <= read_pointer == tx_count;
    end
  end
  
  always_ff @(posedge m_axis_aclk) begin
    if (m_axis_areset || state == IDLE) begin
      read_pointer <= {ADDR_WIDTH{1'b0}}; 
    end else if (tx_en && read_pointer <= tx_count) begin
      read_pointer <= read_pointer + 1;
    end
  end
  
  always_ff @(posedge m_axis_aclk) begin
    if (m_axis_areset) begin
      state <= IDLE;
    end else begin
      case (state)
        IDLE    : state <= tx_start ? ACTIVE : IDLE;
        ACTIVE  : state <= tx_done  ? IDLE   : ACTIVE;
        default : state <= IDLE;
      endcase
    end
  end
  
endmodule
