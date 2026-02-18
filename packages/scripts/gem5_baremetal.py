import argparse,m5
from m5.objects import *
parser = argparse.ArgumentParser()
parser.add_argument( "--elf", type=str, help="ELF to execute")
args = parser.parse_args()
system = System()
system.clk_domain = SrcClockDomain( clock='1GHz', voltage_domain=VoltageDomain())
system.mem_mode = 'timing'
system.mem_ranges = [AddrRange(start=0x80000000, size='256MiB')]
system.cpu = RiscvTimingSimpleCPU()
system.cpu.createInterruptController()
system.membus = SystemXBar()
system.cpu.icache_port = system.membus.cpu_side_ports
system.cpu.dcache_port = system.membus.cpu_side_ports
system.system_port = system.membus.cpu_side_ports  # v22+
system.mem_ctrl = MemCtrl()
system.mem_ctrl.dram = DDR3_1600_8x8()
system.mem_ctrl.dram.device_size = '16MiB'
system.mem_ctrl.dram.range = system.mem_ranges[0]
system.mem_ctrl.port = system.membus.mem_side_ports         # v21.1 and older
system.workload = RiscvBareMetal()
system.workload.bootloader = args.elf
system.cpu.createThreads()
root = Root(full_system=True, system=system)
m5.instantiate()
print("Starting simulation...")
exit_event = m5.simulate()
