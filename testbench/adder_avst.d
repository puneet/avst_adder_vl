import esdl;
import uvm;
import std.stdio;
import std.string: format;

class avst_item: uvm_sequence_item
{
  mixin uvm_object_utils;

  @UVM_DEFAULT {
    @rand ubyte data;
    bool end;
  }
   
  this(string name = "avst_item") {
    super(name);
  }

  constraint! q{
    data >= 0x30;
    data <= 0x7a;
  } cst_ascii;

}

class avst_phrase_seq: uvm_sequence!avst_item
{

  mixin uvm_object_utils;

  @UVM_DEFAULT {
    ubyte[] phrase;
  }

  this(string name="") {
    super(name);
  }

  void set_phrase(string phrase) {
    this.phrase = cast(ubyte[]) phrase;
  }

  bool _is_final;

  bool is_finalized() {
    return _is_final;
  }

  void opOpAssign(string op)(avst_item item) if(op == "~")
    {
      assert(item !is null);
      phrase ~= item.data;
      if (item.end) _is_final = true;
    }
  // task
  override void body() {
    // uvm_info("avst_seq", "Starting sequence", UVM_MEDIUM);

    for (size_t i=0; i!=phrase.length; ++i) {
      wait_for_grant();
      req.data = cast(ubyte) phrase[i];
      if (i == phrase.length - 1) req.end = true;
      else req.end = false;
      avst_item cloned = cast(avst_item) req.clone;
      send_request(cloned);
    }
    
    // uvm_info("avst_item", "Finishing sequence", UVM_MEDIUM);
  } // body

  ubyte[] transform() {
    ubyte[] retval;
    uint value;
    foreach (c; phrase) {
      value += c;
    }
    for (int i=4; i!=0; --i) {
      retval ~= cast (ubyte) (value >> (i-1)*8);
    }
    return retval;
  }
}

class avst_seq: uvm_sequence!avst_item
{
  @UVM_DEFAULT {
    @rand uint seq_size;
  }

  mixin uvm_object_utils;


  this(string name="") {
    super(name);
    req = avst_item.type_id.create(name ~ ".req");
  }

  constraint!q{
    seq_size < 64;
    seq_size > 16;
  } seq_size_cst;

  // task
  override void body() {
      for (size_t i=0; i!=seq_size; ++i) {
	wait_for_grant();
	req.randomize();
	if (i == seq_size - 1) req.end = true;
	else req.end = false;
	avst_item cloned = cast(avst_item) req.clone;
	// uvm_info("avst_item", cloned.sprint, UVM_DEBUG);
	send_request(cloned);
      }
      // uvm_info("avst_item", "Finishing sequence", UVM_DEBUG);
    }

}

class avst_driver: uvm_driver!(avst_item)
{

  mixin uvm_component_utils;
  
  @UVM_BUILD {
    uvm_analysis_port!avst_item req_analysis;
  }

  Top top;

  this(string name, uvm_component parent = null) {
    super(name,parent);
    uvm_config_db!Top.get(this, "", "dut", top);
  }


  override void run_phase(uvm_phase phase) {
    super.run_phase(phase);
    while (true) {
      // uvm_info("AVL TRANSACTION", req.sprint(), UVM_DEBUG);
      // drive_vpi_port.put(req);
      if (top.reset == 1) {
	wait (top.clock.negedge());
	continue;
      }

      if (top.dut.ready_in == 0 && top.dut.valid_out == 0) {
	wait (top.clock.negedge());
	continue;
      }

      if (top.dut.ready_in) {
	seq_item_port.get_next_item(req);


	wait (top.clock.negedge());

	top.dut.data_in = req.data;
	top.dut.end_in = req.end;
	top.dut.valid_in = true;

	wait (top.clock.negedge());

	top.dut.end_in = false;
	top.dut.valid_in = false;

	req_analysis.write(req);
	seq_item_port.item_done();
      }
      else if (top.dut.valid_out) {
	top.dut.ready_out = true;
	wait (top.clock.negedge());
	top.dut.ready_out = false;
      }
    }
  }

  protected void trans_received(avst_item tr) {}
  protected void trans_executed(avst_item tr) {}

}

class avst_req_snooper: uvm_monitor
{
  mixin uvm_component_utils;

  Top top;

  this (string name, uvm_component parent = null) {
    super(name,parent);
    uvm_config_db!Top.get(this, "", "dut", top);
    assert (top !is null);
  }

  @UVM_BUILD {
    uvm_analysis_port!avst_item egress;
  }
  
  override void run_phase(uvm_phase phase) {
    super.run_phase(phase);

    while (true) {
      wait (top.clock.negedge());
      wait (5.nsec);
      if (top.reset == 1 ||
	  top.dut.ready_in == 0 || top.dut.valid_in == 0)
	continue;
      else {
	avst_item item = avst_item.type_id.create(get_full_name() ~ ".avst_item");
	item.data = top.dut.data_in;
	item.end = cast(bool) top.dut.end_in;
	egress.write(item);
	// uvm_info("AVL Monitored Req", item.sprint(), UVM_DEBUG);
	// writeln("valid input");
      }
    }
  }

}

class avst_rsp_snooper: uvm_monitor
{
  mixin uvm_component_utils;

  Top top;

  this (string name, uvm_component parent = null) {
    super(name,parent);
    uvm_config_db!Top.get(this, "", "dut", top);
    assert (top !is null);
  }

  @UVM_BUILD {
    uvm_analysis_port!avst_item egress;
  }
  
  override void run_phase(uvm_phase phase) {
    super.run_phase(phase);

    while (true) {
      wait (top.clock.posedge());
      wait (5.nsec);
      if (top.reset == 1 ||
	  top.dut.ready_out == 0 || top.dut.valid_out == 0)
	continue;
      else {
	avst_item item = avst_item.type_id.create(get_full_name() ~ ".avst_item");
	item.data = top.dut.data_out;
	item.end = cast(bool) top.dut.end_out;
	egress.write(item);
	// uvm_info("AVL Monitored Req", item.sprint(), UVM_DEBUG);
	// writeln("valid input");
      }
    }
  }
}



class avst_scoreboard: uvm_scoreboard
{
  this(string name, uvm_component parent = null) {
    super(name, parent);
  }

  mixin uvm_component_utils;

  uvm_phase phase_run;

  uint matched;

  avst_phrase_seq[] req_queue;
  avst_phrase_seq[] rsp_queue;

  @UVM_BUILD {
    uvm_analysis_imp!(avst_scoreboard, write_req) req_analysis;
    uvm_analysis_imp!(avst_scoreboard, write_rsp) rsp_analysis;
  }

  override void run_phase(uvm_phase phase) {
    phase_run = phase;
    auto imp = phase.get_imp();
    assert(imp !is null);
    uvm_wait_for_ever();
  }

  void write_req(avst_phrase_seq seq) {
    synchronized(this) {
      uvm_info("Monitor", "Got req item", UVM_DEBUG);
      req_queue ~= seq;
      assert(phase_run !is null);
      phase_run.raise_objection(this);
      // writeln("Received request: ", matched + 1);
    }
  }

  void write_rsp(avst_phrase_seq seq) {
    synchronized(this) {
      uvm_info("Monitor", "Got rsp item", UVM_DEBUG);
      // seq.print();
      rsp_queue ~= seq;
      auto expected = req_queue[matched].transform();
      ++matched;
      // writeln("Ecpected: ", expected[0..64]);
      if (expected == seq.phrase) {
	uvm_info("MATCHED",
		 format("Scoreboard received expected response #%d", matched),
		 UVM_LOW);
	uvm_info("REQUEST", format("%s", req_queue[$-1].phrase), UVM_LOW);
	uvm_info("RESPONSE", format("%s", rsp_queue[$-1].phrase), UVM_LOW);
      }
      else {
	uvm_error("MISMATCHED", "Scoreboard received unmatched response");
	writeln(expected, " ~= ", seq.phrase);
      }
      phase_run.drop_objection(this);
    }
  }

}

class avst_monitor: uvm_monitor
{

  mixin uvm_component_utils;
  
  @UVM_BUILD {
    uvm_analysis_port!avst_phrase_seq egress;
    uvm_analysis_imp!(avst_monitor, write) ingress;
  }


  this(string name, uvm_component parent = null) {
    super(name, parent);
  }

  avst_phrase_seq seq;

  void write(avst_item item) {
    if (seq is null) {
      seq = new avst_phrase_seq();
    }
    seq ~= item;
    if (seq.is_finalized()) {
      uvm_info("Monitor", "Got Seq " ~ seq.sprint(), UVM_DEBUG);
      egress.write(seq);
      seq = null;
    }
  }
  
}


class avst_sequencer: uvm_sequencer!avst_item
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent=null) {
    super(name, parent);
  }
}

class avst_agent: uvm_agent
{

  @UVM_BUILD {
    avst_sequencer sequencer;
    avst_driver    driver;

    avst_monitor   req_monitor;
    avst_monitor   rsp_monitor;

    avst_req_snooper   req_snooper;
    avst_rsp_snooper   rsp_snooper;

    avst_scoreboard   scoreboard;
  }
  
  mixin uvm_component_utils;
   
  this(string name, uvm_component parent = null) {
    super(name, parent);
  }

  override void connect_phase(uvm_phase phase) {
    driver.seq_item_port.connect(sequencer.seq_item_export);
    req_snooper.egress.connect(req_monitor.ingress);
    req_monitor.egress.connect(scoreboard.req_analysis);
    rsp_snooper.egress.connect(rsp_monitor.ingress);
    rsp_monitor.egress.connect(scoreboard.rsp_analysis);
  }
}

class random_test: uvm_test
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  @UVM_BUILD {
    avst_env env;
  }
  
  override void run_phase(uvm_phase phase) {
    phase.raise_objection(this);
    phase.get_objection.set_drain_time(this, 20.nsec);
    auto rand_sequence = new avst_seq("avst_seq");

    for (size_t i=0; i!=100; ++i) {
      rand_sequence.randomize();
      auto sequence = cast(avst_seq) rand_sequence.clone();
      sequence.start(env.agent.sequencer, null);
    }
    phase.drop_objection(this);
  }
}

class QuickFoxTest: uvm_test
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  @UVM_BUILD avst_env env;
  
  override void run_phase(uvm_phase phase) {
    phase.raise_objection(this);
    auto sequence = new avst_phrase_seq("QuickFoxSeq");
    sequence.set_phrase("The quick brown fox jumps over the lazy dog");

    sequence.start(env.agent.sequencer, null);
    phase.drop_objection(this);
  }
}

class avst_env: uvm_env
{
  mixin uvm_component_utils;

  @UVM_BUILD private avst_agent agent;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

}

class Top: Entity
{
  import Vadder_avst_euvm;
  import esdl.intf.verilator.verilated;

  VerilatedVcdD _trace;

  Signal!(ubvec!1) reset;
  Signal!(ubvec!1) clock;

  DVadder_avst dut;

  void opentrace(string vcdname) {
    if (_trace is null) {
      _trace = new VerilatedVcdD();
      dut.trace(_trace, 99);
      _trace.open(vcdname);
    }
  }

  void closetrace() {
    if (_trace !is null) {
      _trace.close();
      _trace = null;
    }
  }

  override void doBuild() {
    dut = new DVadder_avst();
    traceEverOn(true);
    opentrace("avst_adder.vcd");
  }
  
  Task!stimulateClock stimulateClockTask;
  Task!stimulateReset stimulateResetTask;
  
  void stimulateClock() {
    import std.stdio;
    clock = false;
    while (true) {
      // writeln("clock is: ", clock);
      clock = false;
      dut.clk = false;
      dut.eval();
      if (_trace !is null)
	_trace.dump(getSimTime().getVal());
      wait (10.nsec);
      clock = true;
      dut.clk = true;
      dut.eval();
      if (_trace !is null) {
	_trace.dump(getSimTime().getVal());
	_trace.flush();
      }
      wait (10.nsec);
    }
  }

  void stimulateReset() {
    reset = true;
    dut.reset = true;
    wait (100.nsec);
    reset = false;
    dut.reset = false;
  }
  
}

class uvm_sha3_tb: uvm_tb
{
  Inst!Top top;
}

void main(string[] args) {
  import std.stdio;

  auto tb = new uvm_sha3_tb;
  tb.multicore(0, 1);
  tb.elaborate("tb", args);
  tb.set_seed(1);
  // tb.setAsyncMode();

  tb.initialize();

  tb.exec_in_uvm_context({
      uvm_config_db!(Top).set(null, "uvm_test_top.env.agent.driver", "dut", tb.top);
      uvm_config_db!(Top).set(null, "uvm_test_top.env.agent.req_snooper", "dut", tb.top);
      uvm_config_db!(Top).set(null, "uvm_test_top.env.agent.rsp_snooper", "dut", tb.top);
    });
			   
  tb.start();
  
}
