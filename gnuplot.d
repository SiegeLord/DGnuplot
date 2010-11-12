module gnuplot;

import tango.io.Stdout;
import tango.sys.Process;
import tango.util.Convert;

import tango.io.device.File;
import tango.sys.Environment;
import tango.io.stream.Text;
import tango.core.Array;

import tango.text.convert.Format;

class C3DPlot : CGNUPlot
{
	this()
	{
		PlotStyle = "image";
	}
	
	this(char[] term)
	{
		PlotStyle = "image";
		super(term);
	}
	
	void View(double[] x_z_rot)
	{
		if(x_z_rot is null)
			opCall("set view map");
		else
			opCall("set view " ~ Format("{}, {}", x_z_rot[0], x_z_rot[1]));
	}
	
	void Palette(char[] pal)
	{
		opCall("set palette " ~ pal);
	}
	
	void Palette(int r_formula, int g_formula, int b_formula)
	{
		opCall("set palette rgbformulae" ~ Format("{} {} {}", r_formula, g_formula, b_formula));
	}
	
	C3DPlot Plot(double[] data, size_t w, size_t h, char[] label = "")
	{
		assert(data.length == w * h, "Width and height don't match the size of the data array");
		
		char[] plot_command;
		
		plot_command ~= `splot "-" matrix`;
		plot_command ~= ` title "` ~ label ~ `" with ` ~ PlotStyle;
		plot_command ~= "\n";
		
		for(int y = 0; y < h; y++)
		{
			for(int x = 0; x < w; x++)
			{
				plot_command ~= Format("{} ", data[y * w + x]);
			}
			plot_command ~= "\n";
		}
		
		plot_command ~= "e\n";
		plot_command ~= "e\n";
		
		opCall(plot_command);
		
		return this;
	}
}

class C2DPlot : CGNUPlot
{
	this()
	{
		PlotStyle = "lines";
	}
	
	this(char[] term)
	{
		PlotStyle = "lines";
		super(term);
	}
	
	C2DPlot Plot(double[] X, double[] Y, char[] label = "")
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
		PlotCommand ~= " with " ~ PlotStyle;
		if(PlotColor.length)
			PlotCommand ~= ` lt rgb "` ~ PlotColor ~ `"`;
		PlotCommand ~= ` lw ` ~ PlotThickness;
		if(StyleHasPoints && PlotPointType.length)
			PlotCommand ~= ` pt ` ~ PlotPointType;
				
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
	
	void Flush()
	{
		opCall("plot " ~ PlotCommand);
		opCall(PlotData);
		
		PlotCommand.length = 0;
		PlotData.length = 0;
	}
	
	void Style(char[] style)
	{
		super.Style(style);
		StyleHasPoints = PlotStyle.length != PlotStyle.find("points");
	}
	
	void PointType(int type)
	{
		if(type < 0)
			PlotPointType = "";
		else
			PlotPointType = Format("{}", type);
	}
	
	C2DPlot Thickness(float thickness)
	{
		assert(thickness >= 0);
		
		PlotThickness = Format("{}", thickness);
		
		return this;
	}
	
	/* Null argument resets color */
	C2DPlot Color(int[3] color)
	{
		if(color is null)
			PlotColor = "";
		else
			PlotColor = Format("#{:x2}{:x2}{:x2}", color[0], color[1], color[2]);
		return this;
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
	
private:	
	char[] PlotCommand;
	char[] PlotData;
	bool StyleHasPoints = false;
	char[] PlotThickness = "1";
	char[] PlotPointType = "0";
	char[] PlotColor = "";
	bool Holding = false;
}

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
	
	void Style(char[] style)
	{
		PlotStyle = style;
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
private:
	Process GNUPlot;
	char[] PlotStyle = "lines";
}
