// bsv libraries
import SpecialFIFOs::*;
import Vector::*;
import StmtFSM::*;
import FIFO::*;

// portz libraries
import Directory::*;
import CtrlMux::*;
import Portal::*;
import PortalMemory::*;
import MemTypes::*;
import MemServer::*;
import SGList::*;
import Leds::*;
import DmaUtils::*;
import HDMI::*;
import PS7LIB::*;
import HostInterface::*;

// generated by tool
import DmaDebugRequestWrapper::*;
import SGListConfigRequestWrapper::*;
import DmaDebugIndicationProxy::*;
import SGListConfigIndicationProxy::*;
import HdmiDisplayRequestWrapper::*;
import HdmiDisplayIndicationProxy::*;
import HdmiInternalIndicationProxy::*;
import HdmiInternalRequestWrapper::*;

// defined by user
import HdmiDisplay::*;

typedef enum {HdmiDisplayRequest, HdmiDisplayIndication, HdmiInternalRequest, HdmiInternalIndication, HostmemDmaDebugIndication, HostmemDmaDebugRequest, HostmemSGListConfigRequest, HostmemSGListConfigIndication} IfcNames deriving (Eq,Bits);

typedef HDMI#(Bit#(16)) HDMI16;

module mkPortalTop#(HostType host)(PortalTop#(PhysAddrWidth,64,HDMI#(Bit#(16)),1));

`ifdef ZynqHostTypeIF
   Clock clk1 = host.fclkclk[1];
`else
   Clock clk1 <- exposeCurrentClock();
`endif
   HdmiInternalIndicationProxy hdmiInternalIndicationProxy <- mkHdmiInternalIndicationProxy(HdmiInternalIndication);
   HdmiDisplayIndicationProxy hdmiDisplayIndicationProxy <- mkHdmiDisplayIndicationProxy(HdmiDisplayIndication);
   HdmiDisplay hdmiDisplay <- mkHdmiDisplay(clk1, hdmiDisplayIndicationProxy.ifc, hdmiInternalIndicationProxy.ifc);
   HdmiDisplayRequestWrapper hdmiDisplayRequestWrapper <- mkHdmiDisplayRequestWrapper(HdmiDisplayRequest,hdmiDisplay.displayRequest);
   HdmiInternalRequestWrapper hdmiInternalRequestWrapper <- mkHdmiInternalRequestWrapper(HdmiInternalRequest,hdmiDisplay.internalRequest);

   Vector#(1,  ObjectReadClient#(64))   readClients = cons(hdmiDisplay.dmaClient, nil);
   SGListConfigIndicationProxy hostmemSGListConfigIndicationProxy <- mkSGListConfigIndicationProxy(HostmemSGListConfigIndication);
   SGListMMU#(PhysAddrWidth) hostmemSGList <- mkSGListMMU(0, True, hostmemSGListConfigIndicationProxy.ifc);
   SGListConfigRequestWrapper hostmemSGListConfigRequestWrapper <- mkSGListConfigRequestWrapper(HostmemSGListConfigRequest, hostmemSGList.request);

   DmaDebugIndicationProxy hostmemDmaDebugIndicationProxy <- mkDmaDebugIndicationProxy(HostmemDmaDebugIndication);
   MemServer#(PhysAddrWidth,64,1) dma <- mkMemServerR(hostmemDmaDebugIndicationProxy.ifc, readClients, cons(hostmemSGList,nil));
   DmaDebugRequestWrapper hostmemDmaDebugRequestWrapper <- mkDmaDebugRequestWrapper(HostmemDmaDebugRequest, dma.request);

   Vector#(8,StdPortal) portals;
   portals[0] = hdmiDisplayRequestWrapper.portalIfc;
   portals[1] = hdmiDisplayIndicationProxy.portalIfc;
   portals[2] = hdmiInternalRequestWrapper.portalIfc;
   portals[3] = hdmiInternalIndicationProxy.portalIfc; 
   portals[4] = hostmemDmaDebugRequestWrapper.portalIfc;
   portals[5] = hostmemDmaDebugIndicationProxy.portalIfc; 
   portals[6] = hostmemSGListConfigRequestWrapper.portalIfc;
   portals[7] = hostmemSGListConfigIndicationProxy.portalIfc;

   
   StdDirectory dir <- mkStdDirectory(portals);
   let ctrl_mux <- mkSlaveMux(dir,portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = dma.masters;
   //interface xadc = hdmiDisplay.xadc;
   interface pins = hdmiDisplay.hdmi;      
endmodule : mkPortalTop

import "BDPI" function Action bdpi_hdmi_vsync(Bit#(1) v);
import "BDPI" function Action bdpi_hdmi_hsync(Bit#(1) v);
import "BDPI" function Action bdpi_hdmi_de(Bit#(1) v);
import "BDPI" function Action bdpi_hdmi_data(Bit#(16) v);
module mkResponder#(HDMI#(Bit#(16)) pins)(Empty);
    rule hvconv;
        bdpi_hdmi_vsync(pins.hdmi_vsync);
    endrule
    rule hvconh;
        bdpi_hdmi_hsync(pins.hdmi_hsync);
    endrule
    rule hvconde;
        bdpi_hdmi_de(pins.hdmi_de);
    endrule
    rule hvcond;
        bdpi_hdmi_data(pins.hdmi_data);
    endrule
endmodule
