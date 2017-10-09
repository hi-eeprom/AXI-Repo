module s_axis_mem #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 5
) (
  input  logic                    s_axis_aclk,
  input  logic                    s_axis_aresetn,
  input  logic                    s_axis_tvalid,
  input  logic [DATA_WIDTH-1:0]   s_axis_tdata,
  input  logic [DATA_WIDTH/8-1:0] s_axis_tstrb,
  input  logic                    s_axis_tlast,
  output logic                    s_axis_tready,
  output logic                    rx_start,
  output logic [ADDR_WIDTH-1:0]   rx_count,
  output logic                    rx_done,
  output logic [DATA_WIDTH/8-1:0] mem_write_be,
  output logic [ADDR_WIDTH-1:0]   mem_write_address,
  output logic [DATA_WIDTH-1:0]   mem_write_data
);
  
  localparam MAX_WORD_COUNT = {ADDR_WIDTH{1'b1}};
  
  logic s_axis_areset;
  assign s_axis_areset = ~s_axis_aresetn;
  
  typedef enum {IDLE,ACTIVE} state_type;
  state_type state;
  
  logic [ADDR_WIDTH-1:0] write_pointer;
  logic rx_en;
  
  assign rx_en = s_axis_tvalid && s_axis_tready;
  assign rx_start = state == IDLE && s_axis_tvalid;
  assign rx_count = write_pointer;
  
  assign s_axis_tready = state == ACTIVE && write_pointer <= MAX_WORD_COUNT;
  
  always_ff @(posedge s_axis_aclk) begin
    mem_write_be <= {DATA_WIDTH/8{rx_en}} & s_axis_tstrb;
    mem_write_address <= write_pointer;
    mem_write_data <= s_axis_tdata;
  end
  
  always_ff @(posedge s_axis_aclk) begin
    if (s_axis_areset) begin
      rx_done <= 1'b0; 
    end else begin
      rx_done <= write_pointer == MAX_WORD_COUNT | s_axis_tlast;
    end
  end
  
  always_ff @(posedge s_axis_aclk) begin
    if (s_axis_areset) begin
      write_pointer <= {ADDR_WIDTH{1'b0}}; 
    end else if (rx_en && write_pointer <= MAX_WORD_COUNT) begin
      write_pointer <= write_pointer + 1;
    end
  end
  
  always_ff @(posedge s_axis_aclk) begin
    if (s_axis_areset) begin
      state <= IDLE;
    end else begin
      case (state)
        IDLE    : state <= rx_start ? ACTIVE : IDLE;
        ACTIVE  : state <= rx_done  ? IDLE   : ACTIVE;
        default : state <= IDLE;
      endcase
    end
  end
  
endmodule
