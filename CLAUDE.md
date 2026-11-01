## 목표
- 매우 간단한 가속기를 SystemVerilog로 설계하고 
- ARM baremetal firmware에서 가속기가 제대로 동작하는지 test함. 
- ARM firmware는 qemu을 사용하고, SystemVerilog를 verilator로 변환하고 systemc로 시뮬레이션함
- 가속기는 AXI4Lite로 int32 a, int32 b를 받아서 kick register가 쓰이면 int32 c에 결과를 쓰고 
- irq가 cpu로 가면 cpu가 결과 c를 가져가는 구조

## 단계
1. desktop에서 qemu로 firmware돌리고 remote-port로 SystemC에 연결해서 테스트함
2. target board에서 SystemVerilog를 PL에 넣고, firmware를 PS넣고 테스트함.

## target board
zynq zybo 7020

## 참고자료
- https://github.com/Xilinx/qemu
- https://github.com/Xilinx/libsystemctlm-soc
- https://github.com/Xilinx/systemctlm-cosim-demo

## nix 사용
- flake.nix로 작성
- nix develop으로 들어가서 build하고 simulation을 실행할 수 있도록 함.

