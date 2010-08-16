require File.expand_path(File.dirname(__FILE__) + '/common')
require_relative '../lib/overlayer'
require_relative '../lib/screen_tracker'
require 'pathname'

describe ScreenTracker do

    def start_vlc
      unless $pid1
        begin
          Win32::Screenshot.window(/silence.wav/, 0) {}
          raise Exception.new('must kill old vlcs first')  unless OS.java? # unexpected, even on jruby <sigh>
        rescue
          # this way we'll only have one up...
          silence = File.expand_path("./silence.wav").gsub("/", "\\")
          $pid1 = Dir.chdir("/program files/VideoLan/VLC") do; IO.popen("vlc.exe #{silence}").pid; end # work around for jruby
          sleep 2
        end
      end
    end
    
    before(:all) do
      start_vlc
    end

    before do
      @a = ScreenTracker.new(/silence.*VLC/,10,10,20,20)
    end

    it "can take a regex or string" do
      ScreenTracker.new(/silence.*VLC/,10,10,20,20)
      ScreenTracker.new("silence",10,10,20,20)
    end

    it "should be able to grab a picture from screen coords...probably from the current active window" do
      @a.get_bmp.should_not be_nil
    end

    it "should loop if unable to find the right window" do
      proc {
        Timeout::timeout(1) do
          ScreenTracker.new("this is supposed to be not running",10,10,20,20)
        end
      }.should raise_error(Timeout::Error)
    end

    it "should be at least somewhat fast" do
      Benchmark.realtime { @a.get_bmp }.should be < 0.3
    end

    it "should not allow for negative widths" do
      proc {ScreenTracker.new("VLC",10,10,-20,20)}.should raise_error
    end

    it "should disallow size 0 widths" do
      proc {ScreenTracker.new("VLC",10,10,0,0)}.should raise_error
    end

    it "should have different bmp if sizes different" do
      a = ScreenTracker.new("VLC",10,10,5,5)
      assert a.get_relative_coords == [10,10,15,15]
      b = ScreenTracker.new("VLC",10,10,50,50)
      assert a.get_bmp != b.get_bmp
    end

    it "should allow for straight desktop if they specify Desktop or desktop" do
      a = ScreenTracker.new("desktop",0,0,100,100)
    end

    context "negative numbers should result in an offset" do

      it "should allow for negative sizes" do
        a = ScreenTracker.new("VLC",-10,10,5,5)
        a.get_bmp
        a = ScreenTracker.new("VLC",-10,-10,10,10) # right to the edge
        a.get_bmp
        a = ScreenTracker.new("VLC",10,-10,5,5)
        a.get_bmp
      end

      it "should assign right coords" do
        a = ScreenTracker.new("VLC",-10,-10,5,5)
        a.get_bmp
        x,y,x2,y2=a.get_relative_coords
        hwnd = Win32::Screenshot::BitmapMaker.hwnd("VLC")
        max_x, max_y = Win32::Screenshot::Util.dimensions_for(hwnd)
        x.should == max_x-10
        y.should == max_y-10
        x2.should == x+5
        y2.should == y+5
      end

      it "should look different with negative than with positive" do
        a = ScreenTracker.new("VLC",10,10,50,50)
        b = ScreenTracker.new("VLC",10,10,50,50)
        c = ScreenTracker.new("VLC",-99,-99,50,50)
        assert a.get_bmp == b.get_bmp
        assert c.get_relative_coords != b.get_relative_coords
        cb = c.get_bmp
        bb = b.get_bmp
        c.get_bmp.length == b.get_bmp.length
        assert c.get_bmp != b.get_bmp
      end

      it "should fail with out of bounds or zero sizes" do
        proc { a = ScreenTracker.new(/silence.*VLC/,-10,10,20,20) }.should raise_error
        proc { a = ScreenTracker.new(/silence.*VLC/,10,-10,20,20) }.should raise_error
        proc { a = ScreenTracker.new(/silence.*VLC/,-10,10,0,2) }.should raise_error
        proc { a = ScreenTracker.new(/silence.*VLC/,10,10,2,0) }.should raise_error
      end

    end

    # lodo: this 7 looks rather redundant...
    it "should parse yaml appropro" do
      yaml = <<-YAML
      name: VLC
      x: 32
      y: 34
      width: 100
      height: 20
      digits:
        :hours:
        :minute_tens:
        - -90
        - 7
        :minute_ones:
        - -82
        - 7
        :second_tens:
        - -72
        - 7
        :second_ones:
        - -66
        - 7      
      YAML
      a = ScreenTracker.new_from_yaml(yaml,nil)
      a.get_relative_coords.should == [32,34,132,54]
    end

    it "should be able to dump its contents" do
      @a.dump_bmp
      assert File.exist?('dump.bmp') && File.exist?('all.dump.bmp')
    end

    context "given a real player that is moving" do

      before do
        @a = ScreenTracker.new("silence.wav", -111, -16, 86, 13)
      end

      it "should be able to poll the screen to know when something changes" do
        @a.wait_till_next_change
        # it updates every 1 second...
        Benchmark.realtime { @a.wait_till_next_change }.should be > 0.2
        @a.dump_bmp # for debugging...
      end

      context "using OCR" do

        before do
          @a = ScreenTracker.new_from_yaml File.read("../zamples/players/total_length_under_an_hour/vlc_non_full_screened.yml"), nil
        end

        it "should be able to disk dump snapshotted digits" do
          @a.dump_bmp
          Pathname.new('minute_tens.bmp').should exist
          Pathname.new('minute_tens.bmp').size.should be > 0
          Pathname.new('hours.bmp').should_not exist
        end

        it "should use OCR against the changes appropriately" do
          output = @a.wait_till_next_change # grab a real change
          output[0].should be_a(String)
          output[0].should include("00:") # like 00:09 or what not...
          output[0].should match(/[1-9]/)
          output[1].should be_a Float
        end
        
        it "should be ok with a failed hours image" do
          @a.stub!(:get_digits_as_bitmaps) do
            four = File.binread('images/4.bmp')
            {:minute_tens=>four,:second_tens => four, :second_ones => four, :minute_ones => four,
              :hours => File.binread('images/black.bmp')}
          end
          @a.attempt_to_get_time_from_screen[0].should == "0:44:44"
        end
        
        context "with an OCR that can change from hour to minutes during ads" do
          it "should detect"
        end

        it "should be able to use invert on images" do
          @a = ScreenTracker.new("silence.wav", -111, -16, 86, 13,
            {:should_invert => true, :hours => nil, :minute_tens => [-90,7], :minute_ones => [-82, 7], :second_tens => [-72, 7], :second_ones => [-66, 7]} )
          got_it = nil
          OCR.stub!(:identify_digit) {|*args|
            got_it = args
          }
          @a.identify_digit('some binary bitmap data')
          got_it[1][:should_invert].should be_true
        end
        
        it "should be able to scan for/identify new windows, since VLC changes signatures" do
          #fail "not possible yet in jruby, so hangs"
          output = @a.wait_till_next_change 
          output[0].should_not be_nil
          old_handle = @a.hwnd
          kill_vlc
          start_vlc
          output = @a.wait_till_next_change 
          output[0].should_not be_nil
          old_handle.should_not == @a.hwnd
        end

      end

      def kill_vlc
        assert $pid1
        # bring redcar to the foreground
        # this seg faults on windows 7 for me for some reason when run inside the editor itself...swt bug?
        unless Socket.gethostname == "PACKRD-1GK7V"
          Win32::Screenshot.window(/universal/, 0) rescue nil
        end
        Process.kill 9, $pid1 # need this process re-started each time or the screen won't change for the screen changing test
        FileUtils.rm_rf Dir['*.bmp']
        $pid1 = nil
      end
      
      after(:all) do
        kill_vlc
      end
    end
  end
