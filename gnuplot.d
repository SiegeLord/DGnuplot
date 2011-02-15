/*
Copyright (c) 2010-2011 Pavel Sountsov

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

   1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.

   2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.

   3. This notice may not be removed or altered from any source
   distribution.
*/

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
		PlotCommand = "splot";
		View = null;
	}

	this(char[] term)
	{
		PlotStyle = "image";
		PlotCommand = "splot";
		super(term);
		View = null;
	}
	
	C3DPlot ZLabel(char[] label)
	{
		Command(`set zlabel "` ~ label ~ `"`);
		return this;
	}

	/* Null argument is auto-scale */
	C3DPlot ZRange(double[] range)
	{
		if(range !is null)
		{
			assert(range.length == 2);
			Command(Format("set zrange [{}:{}]", range[0], range[1]));
		}
		else
			Command("set zrange [*:*]");
			
		return this;
	}

	void View(double[] x_z_rot)
	{
		if(x_z_rot is null)
			Command("set view map");
		else
			Command("set view " ~ Format("{}, {}", x_z_rot[0], x_z_rot[1]));
	}

	void Palette(char[] pal)
	{
		Command("set palette " ~ pal);
	}

	void Palette(int r_formula, int g_formula, int b_formula)
	{
		Command("set palette rgbformulae" ~ Format("{} {} {}", r_formula, g_formula, b_formula));
	}

	C3DPlot Plot(T)(T[] data, size_t w, size_t h, char[] label = "")
	{
		assert(data.length == w * h, "Width and height don't match the size of the data array");

		char[] args;
		char[] plt_data;

		args ~= `"-" matrix`;
		args ~= ` title "` ~ label ~ `" with ` ~ PlotStyle;
		args ~= "\n";

		for(int y = 0; y < h; y++)
		{
			for(int x = 0; x < w; x++)
			{
				plt_data ~= Format("{} ", data[y * w + x]);
			}
			plt_data ~= "\n";
		}

		plt_data ~= "e\n";
		plt_data ~= "e\n";

		PlotRaw(args, plt_data);

		return this;
	}
}

class C2DPlot : CGNUPlot
{
	this()
	{
		PlotStyle = "lines";
		PlotCommand = "plot";
	}

	this(char[] term)
	{
		PlotStyle = "lines";
		PlotCommand = "plot";
		super(term);
	}

	C2DPlot Plot(T)(T[] X, T[] Y, char[] label = "")
	{
		assert(X.length == Y.length, "Arrays must be of equal length to plot.");

		char[] args;
		char[] data;

		args ~= `"-"`;
		args ~= ` title "` ~ label ~ `"`;
		args ~= " with " ~ PlotStyle;
		if(PlotColor.length)
			args ~= ` lt rgb "` ~ PlotColor ~ `"`;
		args ~= ` lw ` ~ PlotThickness;
		if(StyleHasPoints && PlotPointType.length)
			args ~= ` pt ` ~ PlotPointType;

		foreach(ii, x; X)
		{
			auto y = Y[ii];
			data ~= Format("{}\t{}\n", x, y);
		}
		data ~= "e\n";

		PlotRaw(args, data);

		return this;
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

private:
	bool StyleHasPoints = false;
	char[] PlotThickness = "1";
	char[] PlotPointType = "0";
	char[] PlotColor = "";
}

class CGNUPlot
{
	alias opCall Command;

	this()
	{
		GNUPlot = new Process(true, "gnuplot -persist");
		GNUPlot.execute();
	}

	this(char[] term)
	{
		this();
		Command("set term " ~ term);
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

	CGNUPlot PlotRaw(char[] args, char[] data = null)
	{
		if(Hold && PlotArgs.length != 0)
		{
			PlotArgs ~= ", ";
		}
		else
		{
			PlotArgs.length = 0;
			PlotData.length = 0;
		}

		PlotArgs ~= args;
		if(data !is null)
			PlotData ~= data;

		if(!Hold)
			Flush();

		return this;
	}

	void Flush()
	{
		Command(PlotCommand ~ " " ~ PlotArgs);
		Command(PlotData);

		PlotArgs.length = 0;
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
		Command("quit");
	}
	
	void Refresh()
	{
		Command("refresh");
	}

	CGNUPlot XLabel(char[] label)
	{
		return Command(`set xlabel "` ~ label ~ `"`);
	}

	CGNUPlot YLabel(char[] label)
	{
		return Command(`set ylabel "` ~ label ~ `"`);
	}

	/* Null argument is auto-scale */
	CGNUPlot XRange(double[] range)
	{
		if(range !is null)
		{
			assert(range.length == 2);
			return Command(Format("set xrange [{}:{}]", range[0], range[1]));
		}
		else
			return Command("set xrange [*:*]");
	}

	/* Null argument is auto-scale */
	CGNUPlot YRange(double[] range)
	{
		if(range !is null)
		{
			assert(range.length == 2);
			return Command(Format("set yrange [{}:{}]", range[0], range[1]));
		}
		else
			return Command("set yrange [*:*]");
	}

	CGNUPlot Title(char[] title)
	{
		return Command(`set title "` ~ title ~ `"`);
	}

	void Style(char[] style)
	{
		PlotStyle = style;
	}
private:
	char[] PlotStyle = "lines";

	bool Holding = false;
	char[] PlotCommand = "plot";
	char[] PlotArgs;
	char[] PlotData;
	Process GNUPlot;
}
