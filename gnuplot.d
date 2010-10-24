module gnuplot;

import tango.io.Stdout;
import tango.sys.Process;
import tango.util.Convert;

import tango.io.device.File;
import tango.sys.Environment;
import tango.io.stream.Text;

import tango.text.convert.Format;

class CGNUPlot
{
	this()
	{
		GNUPlot = new Process(true, "gnuplot -persist");
		GNUPlot.execute();
	}
	
	this(char[] term)
	{
		this();
		opCall("set term " ~ term);
	}
	
	CGNUPlot opCall(char[] command)
	{
		with(GNUPlot.stdin)
		{
			write(command);
			write("\n");
			flush();
		}
		
		return this;
	}
	
	CGNUPlot XLabel(char[] label)
	{
		return opCall(`set xlabel "` ~ label ~ `"`);
	}
	
	CGNUPlot YLabel(char[] label)
	{
		return opCall(`set ylabel "` ~ label ~ `"`);
	}
	
	/* Null argument is auto-scale */
	CGNUPlot XRange(double[] range)
	{
		if(range !is null)
		{
			assert(range.length == 2);
			return opCall(Format("set xrange [{}:{}]", range[0], range[1]));
		}
		else
			return opCall("set xrange [*:*]");
	}
	
	/* Null argument is auto-scale */
	CGNUPlot YRange(double[] range)
	{
		if(range !is null)
		{
			assert(range.length == 2);
			return opCall(Format("set yrange [{}:{}]", range[0], range[1]));
		}
		else
			return opCall("set yrange [*:*]");
	}
	
	/* Null argument resets color */
	CGNUPlot Color(int[3] color)
	{
		if(color is null)
			PlotColor = "";
		else
			PlotColor = Format("#{:x2}{:x2}{:x2}", color[0], color[1], color[2]);
		return this;
	}
	
	File GetDataFile(int idx)
	{
		auto tmp = Environment.get("TMPDIR", "/tmp/");
		while(idx >= DataFiles.length)
		{
			auto data = new File(tmp ~ "celeme_gnuplot_" ~ to!(char[])(DataFiles.length) ~ ".tmp", File.WriteCreate);
			data.seek(0);
			DataFiles ~= data;
		}
		return DataFiles[idx];
	}
	
	CGNUPlot Plot(double[] X, double[] Y, char[] label = "", bool add = true)
	{
		assert(X.length == Y.length, "Arrays must be of equal length to plot.");
		if(!add)
			DataFileIdx = 0;
		auto data = GetDataFile(DataFileIdx);

		auto output = new TextOutput(data);
		foreach(ii, x; X)
		{
			auto y = Y[ii];
			output.formatln("{}\t{}", x, y);
		}
		output.flush;
			
		char[] command = "";
		command ~= add && HaveOtherPlots ? "replot" : "plot";
		command ~= `"` ~ data.toString ~ `"`;
		command ~= ` title "` ~ label ~ `"`;
		command ~= " with " ~ Style;
		if(PlotColor.length)
			command ~= ` lt rgb "` ~ PlotColor ~ `"`;
		
		HaveOtherPlots = add;
		
		if(HaveOtherPlots)
			DataFileIdx++;
		
		return opCall(command);
	}
	
	void Wait()
	{
		GNUPlot.wait();
	}
	
	void Stop()
	{
		GNUPlot.kill();
	}
	
	void Quit()
	{
		opCall("quit");
	}
	
	bool HaveOtherPlots = false;
	char[] Style = "lines";
	char[] PlotColor = "";
	File[] DataFiles;
	int DataFileIdx = 0;
	Process GNUPlot;
}
