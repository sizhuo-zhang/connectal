.. _Sec:Toolchain:

Workflow using Connectal
========================

In this section, we give an overview of the Connectal workflow and
toolchain.  The complete toolchain, libraries, and many running
examples may be obtained at \textit{www.connectal.org} or by emailing
\textit{connectal@googlegroups.com}.

Top level structure of Connectal applications
---------------------------------------------

The simplest Connectal application consists of 4 files:

Makefile
^^^^^^^^

The top-level Makefile defines parameters for the entire application
build process.  In its simplest form, it specifies which Bluespec
interfaces to use as portals, the hardware and software source files,
and the libraries to use for the hardware and software compilation.

Application Hardware
^^^^^^^^^^^^^^^^^^^^

Connectal applications typically have at least one BSV file containing
declarations of the interfaces being exposed as portals, along with
the implementation of the application hardware itself.

Top.bsv
^^^^^^^

In this file, the developer instantiates the application hardware
modules, connecting them to the generated wrappers and proxies for the
portals exported to software.  To connect to the host processor bus, a
parameterized standard interface is used, making it easy to synthesize
the application for different CPUs or for simulation.  If CPU specific
interface signals are needed by the design (for example, extra clocks
that are generated by the PCIe core), then an optional CPU-specific
interface can also be used.

If the design uses multiple clock domains or additional pins on the
FPGA, those connections are also made here by exporting a 'Pins'
interface.  The Bluespec compiler generates a Verilog module from the
top level BSV module, in which the methods of exposed interfaces are
implemented as Verilog ports. Those ports are associated to physical
pins on the FPGA using a physical constraints file.

Application CPP
^^^^^^^^^^^^^^^

The software portion of a Connectal application generally consists of
at least one C++ file, which instantiates the generated software
portal wrapper and proxies.  The application software is also
responsible for implementing main.

Development cycle
------------------

After creating or editing the source code for the application, the
development cycle consists of four steps: generating makefiles,
compiling the interface, building the application, and running the
application.

Generating Makefiles
^^^^^^^^^^^^^^^^^^^^

Given the parameters specified in the application Makefile and a
platform target specified at the command line, Connectal generates a
target-specific Makefile to control the build process. This Makefile
contains the complete dependency information for the generation of
wrappers/proxies, the use of these wrappers/proxies in compiling both
the software and hardware, and the collection of build artifacts into
a package that can be either run locally or over a network to a remote
'device under test' machine.

Compiling the Interface
^^^^^^^^^^^^^^^^^^^^^^^

The Connectal interface compiler generates the C++ and BSV files to
implement wrappers and proxies for all interfaces specified in the
application Makefile.  Human readable \textbf{JSON} is used as an
intermediate representation of portal interfaces, exposing a useful
debugging window as well as a path for future support of
additional languages and IDLs.

Building the Application
^^^^^^^^^^^^^^^^^^^^^^^^

A target in the generated Makefile invokes GCC to compiler the
software components of the application.  The Bluespec compiler (bsc)
is then invoked to compiler the hardware components to Verilog.  A
parameterized Tcl scripts is used to drive Vivado to build the Xilinx
FPGA configuration bitstream for the design.

A Connectal utility called `fpgamake`_ supports
specification of which Bluespec and Verilog modules should be compiled to
separate netlists and to enable separate place and route of those
netlists given a floor plan. Separate synthesis and floor planning in
this manner can reduce build times, and to make it easier to meet
timing constraints.

Another Connectal utility called `buildcache`_ 
speeds recompilation by caching previous compilation results
and detecting cases where input files have not changed. 
Although similar to the better-known utility \textit{ccache}, this
program has no specific knowledge of the tools being executed,
allowing it to be integrated into any workflow and any tool set.
This utility
uses the system call \textbf{strace} to track which files are read and
written by each build step, computing an 'input signature' of the MD5
checksum for each of these files.  When the input signature matches,
the output files are just refreshed from the cache, avoiding the long
synthesis times for the unchanged portions of the project.

Running the Application
^^^^^^^^^^^^^^^^^^^^^^^

As part of our goal to have a fully scripted design flow, the
generated Makefile includes a \texttt{run} target that will program
the FPGA and launch the specified application or test bench.  In order
to support shared target hardware resources, the developer can direct the run
to a particular machines, which can be accessed over the network.  For
Ubuntu target machines, ssh is used to copy/run the application.  For
Android target machines, 'adb' is used.



Continuous Integration and Debug Support
----------------------------------------

Connectal provides a fully scripted flow in order to make it easy to
automate the building and running of applications for continuous
integration. Our development team builds and runs large collections of
tests whenever the source code repository is updated.

Connectal also provides trace ring buffers in hardware and analysis software
to trace and display the last transactions on the PCIe or AXI memory
bus. This trace is useful when debugging performance or correctness
problems, answering questions of the form:

* What were the last memory requests and responses?
* What was the timing of the last memory request and responses?
* What were the last hardware method invocations or indications?


.. _fpgamake: https://github.com/cambridgehackers/fpgamake
.. _buildcache: https://github.com/cambridgehackers/buildcache
