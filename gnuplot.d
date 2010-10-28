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
	
	CGNUPlot Title(char[] title)
	{
		return opCall(`set title "` ~ title ~ `"`);
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
	
	CGNUPlot Plot(double[] X, double[] Y, char[] label = "")
	{
		assert(X.length == Y.length, "Arrays must be of equal length to plot.");

		if(Hold && PlotCommand.length != 0)
		{
			PlotCommand ~= ", ";
		}
		else
		{
			PlotCommand.length = 0;
			PlotData.length = 0;
		}

		PlotCommand ~= `"-"`;
		PlotCommand ~= ` title "` ~ label ~ `"`;
		PlotCommand ~= " with " ~ Style;
		if(PlotColor.length)
			PlotCommand ~= ` lt rgb "` ~ PlotColor ~ `"`;
		
		foreach(ii, x; X)
		{
			auto y = Y[ii];
			PlotData ~= Format("{}\t{}\n", x, y);
		}
		PlotData ~= "e\n";
		
		if(!Hold)
			Flush();
		
		return this;
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
	
	void Flush()
	{
		opCall("plot " ~ PlotCommand);
		opCall(PlotData);
		
		PlotCommand.length = 0;
		PlotData.length = 0;
	}
	
	void Hold(bool hold)
	{
		Holding = hold;
		if(!Hold)
			Flush();
	}
	
	bool Hold()
	{
		return Holding;
	}
	
	char[] PlotCommand;
	char[] PlotData;
	bool HaveOtherPlots = false;
	char[] Style = "lines";
	char[] PlotColor = "";
	bool Holding = false;
	Process GNUPlot;
}
