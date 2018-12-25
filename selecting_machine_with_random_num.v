`timescale 1ns/1ns
module selecting_machine_with_bell(clk, sw, BTN_7, BTN, row, col, digit_scan, digit_cath, frequncy_bell);
input clk;//clk为周期为20ns频率为50MHZ的时钟
input sw;//sw为开机键
input BTN_7;//BTN_7为最高位按钮，有复位功能
input [6:0] BTN;//BTN为七位数字代表七个按键，高位有效
output [7:0] row;//row为行输出，地、低位有效
output [7:0] col;//col为列输出，高位有效
output [7:0] digit_scan;//Digit_sacn为主模块数码管段选端，高位有效最高位对应a段
output [7:0] digit_cath;//Digit_cath为主模块数码管片选段，低位有效最高位对应最左端数码管
output frequncy_bell;//Frequency_bell为响铃输出，默认值为0
wire [7:0] col_test;//Col_test为basic模块列输出，高位有效
wire [7:0] digit_scan_test;//Digit_scan_test为basic模块数码管片选段，低位有效最高位对应最左端数码管
wire [2:0] bell_code_test;//Bell_code_test为basic模块音符选择码0为静音，1~7对应七个音符


wire [7:0] col_stratup;//Col_startup为startup模块列输出，高位有效
wire [7:0] digit_scan_startup;//Digit_scan_startup为startup模块数码管段选端，高位有效最高位对应a段
wire [2:0] bell_code_startup;//Bell_code_startup为startup模块音符选择码0为静音，1~7对应七个音符
reg u_choose;//u_choose为模块选择1时digit_scan和col和bell_code接startup模块0时接basic模块
wire [2:0] bell_code;//Bell_code为音符选择码0为静音，1~7对应七个音符

initial//初始时u_choose为一
begin
	u_choose=1;
end
always @(posedge clk or posedge BTN_7 or negedge sw) begin
	if (sw==0) begin
		// reset
		u_choose<=1;//关机时顶部输出为startup模块输出
	end
	else if (BTN_7) begin
		u_choose<=0;//按下复位键开始显示选号输出
	end
	else begin
		u_choose<=u_choose;//其他情况下状态不变
	end
end
assign col = u_choose==1? col_stratup : col_test;
assign digit_scan = u_choose==1? digit_scan_startup : digit_scan_test;
assign bell_code = u_choose==1? bell_code_startup : bell_code_test;
//分配顶部输出与基本功能和开机自检之间的关系
selecting_machine_startup u_startup(//实例化开机自检模块
	.clk(clk),
	.sw(sw),
	.col(col_stratup),
	.digit_scan(digit_scan_startup),
	.bell_code(bell_code_startup)
	);
selecting_machine_test u_basic(//实例化基本功能模块
	.clk(clk),
	.rst(BTN_7),
	.BTN(BTN),
	.row(row),
	.col_real(col_test),
	.digit_scan_real(digit_scan_test),
	.digit_cath(digit_cath),
	.bell_code(bell_code_test)
	);

bell u_bell(//实例化铃声译码器模块
	.clk(clk),
	.rst(BTN_7),
	.bell_code(bell_code),
	.frequncy_bell(frequncy_bell)
	);

endmodule

module selecting_machine_startup(clk, sw, col, digit_scan, bell_code);
input clk;//clk为周期为20ns频率为50MHZ的时钟
input sw;//sw为开机键
output reg [7:0] col;//开机自检的列信号输出
output reg [7:0] digit_scan;//开机自检的数码管段选端输出
output reg [2:0] bell_code;//开机自检的铃声信号输出
wire clk_2;//2Hz时钟信号

reg flag;//flag为1时输出信号反向
reg [2:0] cnt;//计数器控制反向次数
initial
begin
	flag<=1;
	cnt<=0;
	col<=0;
	digit_scan<=0;
	bell_code<=0;
end

always @(posedge clk_2) begin
	if (sw==0) begin//关机时输出信号为0，全不亮
		cnt<=0;
		col<=0;
		digit_scan<=0;
		flag<=1;
	end
	else begin//开机时开始闪烁
		if (cnt==6) begin//闪够三次后输出全为0，待机状态
			flag<=0;
			col<=0;
			digit_scan<=0;
			cnt<=0;
		end
		else if (flag==1) begin//flag为1控制反向
			col<=~col;
			digit_scan<=~digit_scan;
			cnt<=cnt+1;
		end
		else begin//其他情况保持待机
			col<=0;
			digit_scan<=0;
		end
	end

end
always @(posedge clk_2) begin//控制输出铃声序列
	case(cnt)
	0:begin
		bell_code<=0;
	end
	1:begin
		bell_code<=7;
	end
	2:begin
		bell_code<=6;
	end
	3:begin
		bell_code<=5;
	end
	4:begin
		bell_code<=4;
	end
	5:begin
		bell_code<=3;
	end
	6:begin
		bell_code<=2;
	end
	default:begin
		bell_code<=0;
	end
	endcase
end


frequency_divider #(.N(12500000)) u_clk_2(//利用分频器输出2Hz时钟信号
	.clkin(clk),
	.clkout(clk_2)
	);

endmodule


module selecting_machine_test(clk, rst, BTN, row, col_real, digit_scan_real, digit_cath, bell_code);
input clk;//clk为周期为20ns频率为50MHZ的时钟
input rst;//复位键
input [6:0] BTN;//BTN为七位数字代表七个按键，高位有效
output [7:0] row;//row为行输出，地、低位有效
output [7:0] col_real;//列输出，高位有效
output [7:0] digit_scan_real;//数码管段选端，高位有效最高位对应a段
output [7:0] digit_cath;//数码管片选段，低位有效最高位对应最左端数码管
output [2:0] bell_code;//音符选择码0为静音，1~7对应七个音符
wire [6:0] flag; //控制器控制输出稳定的中间变量，七位对应七个字符输出
wire [27:0] code;//28为对应七个4位二进制数，每个四位二进制数由一个序列信号发生器控制输出
wire [6:0] clk_seven;//7个时钟信号分别控制7个字符的变化频率
wire clk_500;//500Hz的时钟信号，用于控制译码器扫描信号
wire [6:0] BTN_pulse_temp;//7位对应7个按钮经过消抖后的脉冲信号
wire switch_temp;//控制闪烁的开关信号
wire [7:0] col;//点阵译码器的列信号正常输出
wire [7:0] digit_scan;//数码管段选端的正常输出
wire [2:0] bell_code_BTN;//用于产生按键音的中间码
wire [2:0] bell_code_music;//音乐序列信号转换成的音符信号
assign col_real = col & {8{switch_temp}};
assign digit_scan_real = digit_scan & {8{switch_temp}};
assign bell_code = flag[0]==1?bell_code_BTN:bell_code_music;
//以上三个assign语句可以实现选完号之后的闪烁
sequencer_bell u_sequencer_bell(//实例化音乐序列信号发生器
	.clk(clk),
	.BTN({rst,BTN}),
	.bell_code(bell_code_BTN)
	);
flash f(//实例化闪烁开关信号发生器
	.clk_2(clk_seven[6]),
	.rst(rst),
	.finnal_flag(flag[0]),
	.switch(switch_temp),
	.bell_code(bell_code_music)
	);
flag_control u_flag(//实例化控制器
	.clk(clk),
	.rst(rst),
	.BTN_pulse(BTN_pulse_temp),
	.flag(flag));

debounce #(.N(7)) u_debounce(//实例化按键消抖
	.clk(clk),
	.rst(rst),
	.key(~BTN),
	.key_pulse(BTN_pulse_temp));
	
frequency_divider #(.N(50000)) u_clk_500(//实例化译码器扫描时钟
	.clkin(clk),
	.clkout(clk_500));
frequency_divider #(.N(12500000)) u_clk_6(
	.clkin(clk),
	.clkout(clk_seven[6])
	);
frequency_divider #(.N(10000000)) u_clk_5(
	.clkin(clk),
	.clkout(clk_seven[5])
	);
frequency_divider #(.N(7500000)) u_clk_4(
	.clkin(clk),
	.clkout(clk_seven[4])
	);
frequency_divider #(.N(5000000)) u_clk_3(
	.clkin(clk),
	.clkout(clk_seven[3])
	);
frequency_divider #(.N(2500000)) u_clk_2(
	.clkin(clk),
	.clkout(clk_seven[2])
	);
frequency_divider #(.N(2000000)) u_clk_1(
	.clkin(clk),
	.clkout(clk_seven[1])
	);
frequency_divider #(.N(1250000)) u_clk_0(
	.clkin(clk),
	.clkout(clk_seven[0])
	);
//以上7个分频器分别生成对应7个字符的时钟信号
sequencer_chi u_sequencer_chi(//实例化中文序列信号发生器
	.clk(clk_seven[6]),
	.rst(rst),
	.flag(flag[6]),
	.code(code[27:24])
	);
sequencer_eng u_sequencer_eng(//实例化字母序列信号发生器
	.clk(clk_seven[5]),
	.rst(rst),
	.flag(flag[5]),
	.code(code[23:20])
	);
sequencer_num u_sequencer_num_4(
	.clk(clk_seven[4]),
	.rst(rst),
	.flag(flag[4]),
	.code(code[19:16])
	);
sequencer_num u_sequencer_num_3(
	.clk(clk_seven[3]),
	.rst(rst),
	.flag(flag[3]),
	.code(code[15:12])
	);
sequencer_num u_sequencer_num_2(
	.clk(clk_seven[2]),
	.rst(rst),
	.flag(flag[2]),
	.code(code[11:8])
	);
sequencer_num u_sequencer_num_1(
	.clk(clk_seven[1]),
	.rst(rst),
	.flag(flag[1]),
	.code(code[7:4])
	);
sequencer_num u_sequencer_num_0(//分别实例化5个数字信号发生器
	.clk(clk_seven[0]),
	.rst(rst),
	.flag(flag[0]),
	.code(code[3:0])
	);

decode_seg u_decode_seg(//实例化数码管译码器
	.clk_500(clk_500),
	.rst(rst),
	.code(code[23:0]),
	.digit_seg(digit_scan),
	.digit_cath(digit_cath)
	);

decode_lattice u2(//实例化点阵译码器
.clk_500(clk_500),
.rst(rst),
.code(code[27:24]),
.row(row),
.col(col));
endmodule


module sequencer_eng(clk, rst, flag, code);
input clk;
input rst;
input flag;
output reg [3:0] code;

reg [3:0] cnt;

initial
begin
	code=0;
	cnt=0;
end
always @(posedge clk or posedge rst) begin
	if (rst) begin
		// reset
		cnt<=0;
	end
	else if (cnt==11) begin
		cnt<=0;
	end
	else begin
		cnt<=cnt+1;
	end
	
end
always @(posedge clk or posedge rst) begin
	case(cnt)
	0:begin
		code<=4'hc;
	end
	1:begin
		code<=4'ha;
	end
	2:begin
		code<=4'hd;
	end
	3:begin
		code<=4'hb;
	end
	4:begin
		code<=4'hf;
	end
	5:begin
		code<=4'he;
	end
	6:begin
		code<=4'hc;
	end
	7:begin
		code<=4'ha;
	end
	8:begin
		code<=4'he;
	end
	9:begin
		code<=4'ha;
	end
	10:begin
		code<=4'hf;
	end
	11:begin
		code<=4'hb;
	end
	default:begin
		code<=code;
	end
	endcase
end

endmodule
module sequencer_num(clk, rst, flag, code);
input clk;
input rst;
input flag;
output reg [3:0] code;
reg [3:0] cnt;

initial
begin
	code=0;
	cnt=0;
end
always @(posedge clk or posedge rst) begin
	if (rst) begin
		// reset
		cnt<=0;
	end
	else if (cnt==14) begin
		cnt<=0;
	end
	else begin
		cnt<=cnt+1;
	end
	
end
always @(posedge clk or posedge rst) begin
	case(cnt)
	0:begin
		code<=7;
	end
	1:begin
		code<=1;
	end
	2:begin
		code<=3;
	end
	3:begin
		code<=2;
	end
	4:begin
		code<=9;
	end
	5:begin
		code<=4;
	end
	6:begin
		code<=6;
	end
	7:begin
		code<=0;
	end
	8:begin
		code<=5;
	end
	9:begin
		code<=8;
	end

	default:begin
		code<=code;
	end
	endcase
end

endmodule

module sequencer_chi(clk, rst, flag, code);
input clk;
input rst;
input flag;
output reg [3:0] code;

reg [3:0] cnt;

initial
begin
	code=0;
	cnt=0;
end
always @(posedge clk or posedge rst) begin
	if (rst) begin
		// reset
		cnt<=0;
	end
	else if (cnt==14) begin
		cnt<=0;
	end
	else begin
		cnt<=cnt+1;
	end
	
end
always @(posedge clk or posedge rst) begin
	case(cnt)
	0:begin
		code<=0;
	end
	1:begin
		code<=1;
	end
	2:begin
		code<=3;
	end
	3:begin
		code<=2;
	end
	4:begin
		code<=4;
	end
	5:begin
		code<=1;
	end
	6:begin
		code<=2;
	end
	7:begin
		code<=4;
	end
	8:begin
		code<=0;
	end
	9:begin
		code<=3;
	end
	10:begin
		code<=4;
	end
	11:begin
		code<=2;
	end
	12:begin
		code<=1;
	end
	13:begin
		code<=0;
	end
	14:begin
		code<=3;
	end
	default:begin
		code<=code;
	end
	endcase
end
endmodule

module decode_seg(clk_500, rst, code, digit_seg, digit_cath);//数码管译码器
input clk_500;//500Hz扫描信号
input rst;//复位键
input [23:0] code;//传入的6个4位二进制序列码
output reg [7:0] digit_seg;//数码管段选端
output reg [7:0] digit_cath;//数码管片选段

reg [3:0] digit;//数码管输出控制信号

reg [2:0] cath_control;//输出数码管片选段控制信号
initial
begin
	cath_control<=0;
end

always @(posedge clk_500) begin//控制片选段控制信号从0到5变化
	if (rst) begin
		// reset
		cath_control<=0;
	end
	else if (cath_control==5) begin
		cath_control<=0;
	end
	else  begin
		cath_control<=cath_control+1;
	end
end


always @(posedge clk_500 or posedge rst) begin
	case (digit)
		4'h0:  digit_seg <= 8'b11111100; //显示0~F
        4'h1:  digit_seg <= 8'b01100000;   
        4'h2:  digit_seg <= 8'b11011010;
        4'h3:  digit_seg <= 8'b11110010;
        4'h4:  digit_seg <= 8'b01100110;
        4'h5:  digit_seg <= 8'b10110110;
        4'h6:  digit_seg <= 8'b10111110;
        4'h7:  digit_seg <= 8'b11100000;
        4'h8:  digit_seg <= 8'b11111110;
        4'h9:  digit_seg <= 8'b11110110;
        4'hA:  digit_seg <= 8'b11101110;//显示A
        4'hB:  digit_seg <= 8'b10011100;//显示C
        4'hC:  digit_seg <= 8'b10011110;//显示E
        4'hD:  digit_seg <= 8'b10001110;//显示F
        4'hE:  digit_seg <= 8'b01101110;//显示H
        4'hF:  digit_seg <= 8'b00011100;//显示L
		default:;
	endcase
end

always @(posedge clk_500) begin//在对应的片上给数码管的段选信号赋值
	case(cath_control)
	3'h0: begin
		digit_cath<=8'b1111_1110;
		digit<=code[3:0];
	end
	3'h1: begin
		digit_cath<=8'b1111_1101;
		digit<=code[7:4];
	end
	3'h2: begin
		digit_cath<=8'b1111_1011;
		digit<=code[11:8];
	end
	3'h3: begin
		digit_cath<=8'b1111_0111;
		digit<=code[15:12];
	end
	3'h4: begin
		digit_cath<=8'b1110_1111;
		digit<=code[19:16];
	end
	3'h5: begin
		digit_cath<=8'b1101_1111;
		digit<=code[23:20];
	end
	default:;
	endcase
end

endmodule

module decode_lattice(clk_500, rst, code, row, col);//点阵译码器
input clk_500;//50MHz时钟信号
input rst;//复位信号
input [3:0] code;//四位二进制汉字编码
output reg [7:0] row;//输出行信号
output reg [7:0] col;//输出列信号

reg [63:0] col_temp;//列信号暂存器，存有一个汉字的8*8点阵信息

reg [2:0] cnt;//三位二进制数计数器
initial
begin
	cnt<=0;
end
always @(posedge clk_500) begin//控制计数器以500Hz的频率从0到7计数
	if (rst) begin
		// reset
		cnt<=0;
	end
	else  begin
		cnt<=cnt+1;
	end
end

always @(posedge clk_500) begin//计数器走到第i个第i行开始工作，对第i行进行相应的赋值
	case(cnt)
	3'h0: begin
		row<=8'b1111_1110;
		col<=col_temp[7:0];
	end
	3'h1: begin
		row<=8'b1111_1101;
		col<=col_temp[15:8];
	end
	3'h2: begin
		row<=8'b1111_1011;
		col<=col_temp[23:16];
	end
	3'h3: begin
		row<=8'b1111_0111;
		col<=col_temp[31:24];
	end
	3'h4: begin
		row<=8'b1110_1111;
		col<=col_temp[39:32];
	end
	3'h5: begin
		row<=8'b1101_1111;
		col<=col_temp[47:40];
	end
	3'h6: begin
		row<=8'b1011_1111;
		col<=col_temp[55:48];
	end
	3'h7: begin
		row<=8'b0111_1111;
		col<=col_temp[63:56];
	end
	default:;
	endcase
end


always @(posedge clk_500) begin
	case(code)
        4'h0:  col_temp <= 64'b00010000_11111111_01111110_01000010_01111110_01010100_11010010_10110000;//京
        4'h1:  col_temp <= 64'b11000100_01011111_10010001_00011111_01010001_01010000_10100000_10100000;//沪
        4'h2:  col_temp <= 64'b00011000_11111111_00011000_01111110_00000000_01111110_01000010_01111110;//吉
        4'h3:  col_temp <= 64'b00100100_11111111_00010000_11111100_01010110_10100101_01100100_11001100;//苏
        4'h4:  col_temp <= 64'b01001001_01001001_01001001_01001001_01001001_01001001_01001001_10001001;//川
	endcase
end

endmodule


module flag_control(clk, rst, BTN_pulse, flag);//控制器
input clk;//50MHz时钟信号
input rst;//复位信号
input [6:0] BTN_pulse;//传入的7位脉冲信号
output reg [6:0] flag;//输出的7位控制变量
initial begin//开始时所有控制变量为1，即7位字符均在变化
flag<=7'b111_1111;
end

always @(posedge clk or posedge rst ) begin
	if (rst) begin//若复位键被按下，所有控制变量重新为1，即7位字符均重新开始变化
		// reset
		flag <= 7'b111_1111;
	end
	else if (BTN_pulse[6]) begin//若最高位按键脉冲产生则汉字的控制变量为0，汉字输出稳定
		flag[6]<=0;
	end
	else if (BTN_pulse[5] & flag[6] == 0) begin//必须有上一位为0使这一位控制变量才能被置为0
		flag[5]<=0;
	end
	else if (BTN_pulse[4] & flag[5] == 0) begin//必须有上一位为0使这一位控制变量才能被置为0
		flag[4]<=0;
	end
	else if (BTN_pulse[3] & flag[4] == 0) begin//必须有上一位为0使这一位控制变量才能被置为0
		flag[3]<=0;
	end
	else if (BTN_pulse[2] & flag[3] == 0) begin//必须有上一位为0使这一位控制变量才能被置为0
		flag[2]<=0;
	end
	else if (BTN_pulse[1] & flag[2] == 0) begin//必须有上一位为0使这一位控制变量才能被置为0
		flag[1]<=0;
	end
	else if (BTN_pulse[0] & flag[1] == 0) begin//必须有上一位为0使这一位控制变量才能被置为0
		flag[0]<=0;
	end
	else begin
		flag<=flag;//其他情况下控制变量不变
	end
end

endmodule


 module debounce (clk,rst,key,key_pulse);
 
        parameter       N  =  1;                      //要消除的按键的数量
 
	input             clk;
        input             rst;
        input 	[N-1:0]   key;                        //输入的按键					
	output  [N-1:0]   key_pulse;                  //按键动作产生的脉冲	
 
        reg     [N-1:0]   key_rst_pre;                //定义一个寄存器型变量存储上一个触发时的按键值
        reg     [N-1:0]   key_rst;                    //定义一个寄存器变量储存储当前时刻触发的按键值
 
        wire    [N-1:0]   key_edge;                   //检测到按键由高到低变化是产生一个高脉冲
 
        //利用非阻塞赋值特点，将两个时钟触发时按键状态存储在两个寄存器变量中
        always @(posedge clk  or  posedge rst)
          begin
             if (rst) begin
                 key_rst <= {N{1'b1}};                //初始化时给key_rst赋值全为1，{}中表示N个1
                 key_rst_pre <= {N{1'b1}};
             end
             else begin
                 key_rst <= key;                     //第一个时钟上升沿触发之后key的值赋给key_rst,同时key_rst的值赋给key_rst_pre
                 key_rst_pre <= key_rst;             //非阻塞赋值。相当于经过两个时钟触发，key_rst存储的是当前时刻key的值，key_rst_pre存储的是前一个时钟的key的值
             end    
           end
 
        assign  key_edge = key_rst_pre & (~key_rst);//脉冲边沿检测。当key检测到下降沿时，key_edge产生一个时钟周期的高电平
 
        reg	[17:0]	  cnt;                       //产生延时所用的计数器，系统时钟12MHz，要延时20ms左右时间，至少需要18位计数器     
 
        //产生20ms延时，当检测到key_edge有效是计数器清零开始计数
        always @(posedge clk or posedge rst)
           begin
             if(rst)
                cnt <= 18'h0;
             else if(key_edge)
                cnt <= 18'h0;
             else
                cnt <= cnt + 1'h1;
             end  
 
        reg     [N-1:0]   key_sec_pre;                //延时后检测电平寄存器变量
        reg     [N-1:0]   key_sec;                    
 
 
        //延时后检测key，如果按键状态变低产生一个时钟的高脉冲。如果按键状态是高的话说明按键无效
        always @(posedge clk  or  posedge rst)
          begin
             if (rst) 
                 key_sec <= {N{1'b1}};                
             else if (cnt==18'h3ffff)
                 key_sec <= key;  
          end
       always @(posedge clk  or  posedge rst)
          begin
             if (rst)
                 key_sec_pre <= {N{1'b1}};
             else                   
                 key_sec_pre <= key_sec;             
         end      
       assign  key_pulse = key_sec_pre & (~key_sec);     
       initial
       begin
       	cnt<=0;
       	key_rst<=0;
       	key_rst_pre<=0;
       	key_sec_pre<=0;
       	key_sec<=0;
       end
 
endmodule

module flash(clk_2, rst, finnal_flag, switch, bell_code);//闪烁模块
input clk_2;//输入2Hz时钟
input rst;//复位键
input finnal_flag;//检测最末位的控制信号是否为0，即选号过程是否结束
output reg switch;//输出控制闪烁的开关变量
output reg [2:0] bell_code;//输出选号结束时的音乐序列
reg [2:0] cnt;//控制闪烁次数的计数器
initial
begin
	switch<=1;//正常情况下开关变量为1不变
	cnt<=0;
	bell_code<=0;
end

always @(posedge clk_2 or posedge rst) begin
	if (rst) begin
		// reset
		switch<=1;
		cnt<=0;
	end
	else if (finnal_flag==0 &cnt<6) begin//计数器不满且选号结束时开关反向
		switch<=~switch;
		cnt<=cnt+1;
	end
	else if (cnt==6) begin//计数器满时开关置1，计数器无效
		switch<=1;
		cnt<=7;
	end
	else begin
		switch<=switch;
	end
end

always @(posedge clk_2) begin//利用计数器产生选号完成后的音乐
	case(cnt)
	0:begin
		bell_code<=0;
	end
	1:begin
		bell_code<=1;
	end
	2:begin
		bell_code<=2;
	end
	3:begin
		bell_code<=3;
	end
	4:begin
		bell_code<=4;
	end
	5:begin
		bell_code<=5;
	end
	6:begin
		bell_code<=6;
	end
	default:begin
		bell_code<=0;
	end
	endcase
end
endmodule

module bell(clk, rst, bell_code, frequncy_bell);
input clk;//50M
input rst;//复位键
input [2:0] bell_code;
output reg frequncy_bell; //响铃输出
wire [6:0] frequncy_bell_temp;//七个音符
frequency_divider #(.N(23889)) bell_clk_1(//1046.5Hz 高音1
	.clkin(clk),
	.clkout(frequncy_bell_temp[0])
	);
frequency_divider #(.N(21282)) bell_clk_2(//1174.7Hz 高音2
	.clkin(clk),
	.clkout(frequncy_bell_temp[1])
	);
frequency_divider #(.N(18961)) bell_clk_3(//1318.5Hz 高音3
	.clkin(clk),
	.clkout(frequncy_bell_temp[2])
	);
frequency_divider #(.N(17897)) bell_clk_4(//1396.9Hz 高音4
	.clkin(clk),
	.clkout(frequncy_bell_temp[3])
	);
frequency_divider #(.N(15944)) bell_clk_5(//1568Hz 高音5
	.clkin(clk),
	.clkout(frequncy_bell_temp[4])
	);
frequency_divider #(.N(14205)) bell_clk_6(//1760Hz 高音6
	.clkin(clk),
	.clkout(frequncy_bell_temp[5])
	);
frequency_divider #(.N(12655)) bell_clk_7(//1975.5Hz 高音7
	.clkin(clk),
	.clkout(frequncy_bell_temp[6])
	);
always @(posedge clk or posedge rst) begin
	case(bell_code)
	1:begin
		frequncy_bell<=frequncy_bell_temp[0];
	end
	2:begin
		frequncy_bell<=frequncy_bell_temp[1];
	end
	3:begin
		frequncy_bell<=frequncy_bell_temp[2];
	end
	4:begin
		frequncy_bell<=frequncy_bell_temp[3];
	end
	5:begin
		frequncy_bell<=frequncy_bell_temp[4];
	end
	6:begin
		frequncy_bell<=frequncy_bell_temp[5];
	end
	7:begin
		frequncy_bell<=frequncy_bell_temp[6];
	end
	0:begin
		frequncy_bell<=0;
	end
	default:begin
		frequncy_bell<=frequncy_bell_temp[0];
	end
	endcase
end
endmodule

module sequencer_bell(clk, BTN, bell_code);//音乐序列信号发生器
input clk;
input [7:0] BTN;
output reg [2:0] bell_code;
always @(posedge clk) begin
	case(BTN)
	8'b0000_0001:begin
		bell_code<=1;
	end
	8'b0000_0010:begin
		bell_code<=2;
	end
	8'b0000_0100:begin
		bell_code<=3;
	end
	8'b0000_1000:begin
		bell_code<=4;
	end
	8'b0001_0000:begin
		bell_code<=5;
	end
	8'b0010_0000:begin
		bell_code<=6;
	end
	8'b0100_0000:begin
		bell_code<=7;
	end
	default:begin
		bell_code<=0;
	end
	endcase
end
endmodule

module frequency_divider(clkin, clkout);//分频器
parameter N = 1;//输出时钟周期为2N+2倍的T0
input clkin;
output reg clkout;
reg [27:0] cnt;//控制输出时钟反向的计数器
initial 
begin
cnt=0;
clkout<=0;
end
always @(posedge clkin) begin
	if (cnt==N) begin//计数器计满输出时钟反向
		clkout <= !clkout;
		cnt <= 0;
	end
	else begin
		cnt <= cnt + 1;
	end
end
endmodule
