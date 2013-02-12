#!/usr/bin/python
import os, sys, shutil, string
import AST
import bsvgen
import xpsgen
import cppgen
import syntax
import argparse
import util

AST.Function.__bases__ += (cppgen.NoCMixin,)
AST.Module.__bases__ += (cppgen.NoCMixin,)
AST.Method.__bases__ += (cppgen.MethodMixin,bsvgen.MethodMixin)
AST.StructMember.__bases__ += (cppgen.StructMemberMixin,)
AST.Struct.__bases__ += (cppgen.StructMixin,bsvgen.NullMixin)
AST.EnumElement.__bases__ += (cppgen.EnumElementMixin,)
AST.Enum.__bases__ += (cppgen.EnumMixin,bsvgen.NullMixin)
AST.Type.__bases__ += (cppgen.TypeMixin,bsvgen.TypeMixin)
AST.Param.__bases__ += (cppgen.ParamMixin,)
AST.Interface.__bases__ += (cppgen.InterfaceMixin,bsvgen.InterfaceMixin,xpsgen.InterfaceMixin)

argparser = argparse.ArgumentParser("Generate C++/BSV/Xilinx stubs for an interface.")

argparser.add_argument('bsvfile', help='BSV files to parse', nargs='+')
argparser.add_argument('-b', '--interface', help='BSV interface to generate stubs for')
argparser.add_argument('-p', '--project-dir', default='./xpsproj', help='xps project directory')

makefileTemplate='''
BSVPATH = %(bsvpath)s
vfile=pcores/%(corename)s/hdl/verilog/mk%(Dut)sWrapper.v
paofile=pcores/%(corename)s/data/%(corename)s_v2_1_0.pao

$(vfile): pcores/%(corename)s/hdl/verilog/%(Dut)sWrapper.bsv
	cd pcores/%(corename)s/hdl/verilog; bsc -p +:$(BSVPATH) -verilog -u -g mk%(Dut)sWrapper %(Dut)sWrapper.bsv

%(dut)s.make: %(dut)s.xmp
	xps %(dut)s.xmp

verilog: $(vfile)
	./updatepao.sh $(vfile) $(paofile) $(BSVPATH)

netlist: pcores/%(corename)s/hdl/verilog/mk%(Dut)sWrapper.v %(dut)s.make
	make -f %(dut)s.make netlist

bits: pcores/%(corename)s/hdl/verilog/mk%(Dut)sWrapper.v %(dut)s.make
	make -f %(dut)s.make bits
'''

if __name__=='__main__':
    namespace = argparser.parse_args()
    print namespace

    project_dir = os.path.expanduser(namespace.project_dir)

    for inputfile in namespace.bsvfile:
        s = open(inputfile).read() + '\n'
        s1 = syntax.parse(s)

    corename = '%s_v1_00_a' % namespace.interface.lower()

    makename = os.path.join(project_dir, 'Makefile')
    xmpname = os.path.join(project_dir, '%s.xmp' % namespace.interface.lower())
    mhsname = os.path.join(project_dir, '%s.mhs' % namespace.interface.lower())

    hname = os.path.join(project_dir, 'driver', '%s.h' % namespace.interface)
    h = util.createDirAndOpen(hname, 'w')
    cppname = os.path.join(project_dir, 'driver', '%s.cpp' % namespace.interface)
    bsvname = os.path.join(project_dir, 'pcores', corename, 'hdl', 'verilog',
                           '%sWrapper.bsv' % namespace.interface)
    vhdname = os.path.join(project_dir, 'pcores', corename, 'hdl', 'vhdl',
                           '%s.vhd' % namespace.interface)
    mpdname = os.path.join(project_dir, 'pcores', corename, 'data',
                           '%s_v2_1_0.mpd' % namespace.interface.lower())
    paoname = os.path.join(project_dir, 'pcores', corename, 'data',
                           '%s_v2_1_0.pao' % namespace.interface.lower())
    print 'Writing CPP header', hname
    print 'Writing CPP wrapper', cppname
    cpp = util.createDirAndOpen(cppname, 'w')
    cpp.write('#include "ushw.h"\n')
    cpp.write('#include "%s.h"\n' % namespace.interface)
    print 'Writing BSV wrapper', bsvname
    bsv = util.createDirAndOpen(bsvname, 'w')
    bsvgen.emitPreamble(bsv, namespace.bsvfile)

    ## code generation pass
    for v in syntax.globaldecls:
        v.emitCDeclaration(h)
        v.emitCImplementation(cpp)
    if (syntax.globalvars.has_key(namespace.interface)):
        subinterface = syntax.globalvars[namespace.interface]

        for d in subinterface.decls:
            if d.type == 'Interface':
                if syntax.globalvars.has_key(d.name):
                    subintdef = syntax.globalvars[d.name]
                    print d.params
                    newint = subintdef.instantiate({'a': d.params[0]})
                    print newint
                    for sd in newint.decls:
                        sd.name = '%s.%s' % (d.name, sd.name)
                        subinterface.decls.append(sd)

        subinterface.emitCDeclaration(h)
        subinterface.emitCImplementation(cpp)

        subinterface.emitBsvImplementation(bsv)
        subinterface.writeMpd(mpdname)
        subinterface.writeMhs(mhsname)
        subinterface.writeXmp(xmpname)
        subinterface.writePao(paoname)
        subinterface.writeVhd(vhdname)
    if cppname:
        srcdir = os.path.join(os.path.dirname(sys.argv[0]), 'cpp')
        dstdir = os.path.dirname(cppname)
        for f in ['ushw.h', 'ushw.cpp']:
            shutil.copyfile(os.path.join(srcdir, f), os.path.join(dstdir, f))
    shutil.copyfile(os.path.join(os.path.dirname(sys.argv[0]), 'updatepao.sh'),
                    os.path.join(project_dir, 'updatepao.sh'))
    shutil.copymode(os.path.join(os.path.dirname(sys.argv[0]), 'updatepao.sh'),
                    os.path.join(project_dir, 'updatepao.sh'))

    print 'Writing Makefile', makename
    make = util.createDirAndOpen(makename, 'w')
    make.write(makefileTemplate % {'corename': corename,
                                   'dut': namespace.interface.lower(),
                                   'Dut': util.capitalize(namespace.interface),
                                   'bsvpath': os.path.dirname(namespace.bsvfile[0])
                                   })

    print '############################################################'
    print '## To build:'
    print '    cd %s; make bits' % (project_dir)
    print '## You can use XPS to generate bit file or exit and let make complete the process.'
