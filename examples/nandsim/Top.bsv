// bsv libraries
import SpecialFIFOs::*;
import Vector::*;
import StmtFSM::*;
import FIFO::*;
import BRAM::*;
import DefaultValue::*;

// portz libraries
import AxiClientServer::*;
import AxiMasterSlave::*;
import Directory::*;
import CtrlMux::*;
import Portal::*;
import PortalMemory::*;
import PortalRMemory::*;
import AxiRDMA::*;

// generated by tool
import NandSimRequestWrapper::*;
import DMARequestWrapper::*;
import NandSimIndicationProxy::*;
import DMAIndicationProxy::*;

// defined by user
import NandSim::*;

module mkPortalTop(StdPortalDmaTop);

   DMAIndicationProxy dmaIndicationProxy <- mkDMAIndicationProxy(9);

   NandSimIndicationProxy nandSimIndicationProxy <- mkNandSimIndicationProxy(7);
   
   BRAM1Port#(Bit#(14), Bit#(64)) br <- mkBRAM1Server(defaultValue);
   NandSim nandSim <- mkNandSim(nandSimIndicationProxy.ifc, br.portA);
   NandSimRequestWrapper nandSimRequestWrapper <- mkNandSimRequestWrapper(1008,nandSim.request);

   Vector#(1, DMAReadClient#(64)) readClients = cons(nandSim.readClient, nil);
   Vector#(1, DMAWriteClient#(64)) writeClients = cons(nandSim.writeClient, nil);
   Integer             numRequests = 2;
   AxiDMAServer#(64,8) dma <- mkAxiDMAServer(dmaIndicationProxy.ifc, numRequests, readClients, writeClients);

   DMARequestWrapper dmaRequestWrapper <- mkDMARequestWrapper(1005,dma.request);

   Vector#(4,StdPortal) portals;
   portals[0] = nandSimRequestWrapper.portalIfc;
   portals[1] = nandSimIndicationProxy.portalIfc; 
   portals[2] = dmaRequestWrapper.portalIfc;
   portals[3] = dmaIndicationProxy.portalIfc; 
   
   Directory dir <- mkDirectory(portals);
   Vector#(1,StdPortal) directories;
   directories[0] = dir.portalIfc;
   
   // when constructing ctrl and interrupt muxes, directories must be the first argument
   let ctrl_mux <- mkAxiSlaveMux(directories,portals);
   let interrupt_mux <- mkInterruptMux(portals);
   
   interface ReadOnly interrupt = interrupt_mux;
   interface StdAxi3Slave ctrl = ctrl_mux;
   interface Vector m_axi = replicate(dma.m_axi);
endmodule : mkPortalTop
