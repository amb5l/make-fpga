### make-fpga
This repository contains makefiles that can simplify the use of [GNU make](https://www.gnu.org/software/make/) to drive the design and verification of FPGAs.

The following tools are supported at present:

<table>
  <tr>
    <th>File Name</th>
    <th>Tool</th>
    <th>Application</th>
  </tr>
  <tr>
    <td>vivado.mak</td>
    <td>AMD/Xilinx Vivado</td>
    <td>mixed language synthesis, implementation and simulation</td>
  </tr>
  <tr>
    <td>vivado_post.mak</td>
    <td>AMD/Xilinx Vivado</td>
    <td>post-synthesis functional simulation</td>
  </tr>
  <tr>
    <td>vitis.mak</td>
    <td>AMD/Xilinx Vitis</td>
    <td>MicroBlaze, MicroBlaze-V and ARM CPU software builds</td>
  </tr>
  <tr>
    <td>vsim.mak</td>
    <td>Siemens ModelSim/Questa</td>
    <td>mixed language simulation</td>
  </tr>
  <tr>
    <td>ghdl.mak</td>
    <td>GHDL</td>
    <td>VHDL simulation</td>
  </tr>
  <tr>
    <td>nvc.mak</td>
    <td>NVC</td>
    <td>VHDL simulation</td>
  </tr>
</table>

Support for Intel/Altera Quartus Prime is planned.

Please note that the repository contains various other makefiles and scripts, in addition to the above - these are deprecated and will eventually disappear.