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

/**
 * This is a simple <a href="http://www.gnuplot.info/">gnuplot</a> controller. The term controller
 * in this context means that this code spawns a gnuplot process and controls it via
 * pipes. Two syntaxes are supported by this code:
 *
 * ---
 * (new CGNUPlot()).Title("Test Plot").XRange([-1, 1]).YRange([-1, 1]).PlotRaw("x*x*x");
 * ---
 *
 * Or this syntax:
 *
 * ---
 * auto plot = new CGNUPlot();
 * with(plot)
 * {
 *     Title = "Test Plot";
 *     XRange = [-1, 1];
 *     YRange = [-1, 1];
 *     PlotRaw("x*x*x");
 * }
 * ---
 */

module gnuplot;

import tango.io.Stdout;
import tango.sys.Process;

import tango.core.Array;
import tango.math.Math;

import tango.text.convert.Format;
import tango.text.convert.Layout;

version(linux)
{
	import tango.stdc.posix.poll;
}

private template IsArray(T)
{
	const IsArray = is(typeof(T.length)) && is(typeof(T[0]));
}

private struct STextSink(T)
{
	alias Sink opCatAssign;

	uint Sink(T[] input)
	{
		auto len = input.length;
		auto new_size = Size + len;

		if(new_size > Data.length)
			Reserve(new_size * 3 / 2);

		Data[Size..new_size] = input[];

		Size = new_size;

		return len;
	}

	void Reserve(size_t amt)
	{
		if(amt > Data.length)
			Data.length = amt;
	}

	T[] opSlice()
	{
		return Data[0..Size];
	}

	T[] Data;
	size_t Size = 0;
}

/**
 * A 3D data plotter.
 */
class C3DPlot : CGNUPlot
{
	/**
	 * See_Also:
	 *     $(SYMLINK CGNUPlot.this, CGNUPlot.this)
	 */
	this()
	{
		PlotStyle = "image";
		PlotCommand = "splot";
		View = null;
	}

	/**
	 * See_Also:
	 *     $(SYMLINK CGNUPlot.this, CGNUPlot.this)
	 */
	this(char[] term)
	{
		PlotStyle = "image";
		PlotCommand = "splot";
		super(term);
		View = null;
	}

	/**
	 * Set the label for the Z axis.
	 *
	 * Params:
	 *     label = Label text.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	C3DPlot ZLabel(char[] label)
	{
		Command(`set zlabel "` ~ label ~ `"`);
		return this;
	}

	/**
	 * Set the range of the Z axis.
	 *
	 * Params:
	 *     range = An array of two doubles specifying the minimum and the maximum.
	 *             Pass $(DIL_KW null) to make the axis auto-scale.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	C3DPlot ZRange(double[] range)
	{
		if(range !is null)
		{
			assert(range.length == 2);
			Command(Format("set zrange [{:e6}:{:e6}]", range[0], range[1]));
		}
		else
			Command("set zrange [*:*]");

		return this;
	}
	
	/**
	 * Set the range of the colobar.
	 *
	 * Params:
	 *     range = An array of two doubles specifying the minimum and the maximum.
	 *             Pass $(DIL_KW null) to make the axis auto-scale.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	C3DPlot CRange(double[] range)
	{
		if(range !is null)
		{
			assert(range.length == 2);
			Command(Format("set cbrange [{:e6}:{:e6}]", range[0], range[1]));
		}
		else
			Command("set cbrange [*:*]");

		return this;
	}

	/**
	 * Enable logarithmic scale for the Z axis. Keep in mind that the minimum and
	 * maximum ranges need to be positive for this to work.
	 *
	 * Params:
	 *     use_log = Whether or not to actually set the logarithmic scale.
	 *     base = Base used for the logarithmic scale.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	CGNUPlot ZLogScale(bool use_log = true, int base = 10)
	{
		if(use_log)
			Command(Format("set logscale z {}", base));
		else
			Command("unset logscale z");

		return this;
	}

	/**
	 * Set the view direction.
	 *
	 * Params:
	 *     x_z_rot = Rotation around the x and the z axes, in degrees. Pass $(DIL_KW null)
	 *               to set the "map" view, suitable for image plots.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	C3DPlot View(double[] x_z_rot)
	{
		if(x_z_rot is null)
			Command("set view map");
		else
			Command("set view " ~ Format("{}, {}", x_z_rot[0], x_z_rot[1]));

		return this;
	}

	/**
	 * Set the palette. This can be either "color" or "gray".
	 *
	 * Params:
	 *     pal = Name of the palette.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	C3DPlot Palette(char[] pal)
	{
		Command("set palette " ~ pal);

		return this;
	}

	/**
	 * Set the palette using the RGB formulae. The default is 7, 5, 15. See the gnuplot
	 * documentation or the internet for more options.
	 *
	 * Params:
	 *     triplet = Formula indexes.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	C3DPlot Palette(int[3] triplet...)
	{
		Command("set palette rgbformulae" ~ Format(" {},{},{}", triplet[0], triplet[1], triplet[2]));

		return this;
	}

	/**
	 * Plot a rectangular matrix of values.
	 *
	 * Params:
	 *     data = Linear array to the data or a numerical constant. Assumes row-major storage.
	 *     w = Width of the array.
	 *     h = Height of the array.
	 *     label = Label text to use for this surface.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	C3DPlot Plot(Data_t)(Data_t data, size_t w, size_t h, char[] label = "")
	{
		const arr = IsArray!(Data_t);
		static if(arr)
			assert(data.length == w * h, "Width and height don't match the size of the data array");

		ArgsSink.Size = 0;
		DataSink.Size = 0;
		DataSink.Reserve(w * h * 15);

		ArgsSink ~= `"-" matrix`;
		ArgsSink ~= ` title "` ~ label ~ `" with ` ~ PlotStyle;
		ArgsSink ~= "\n";

		for(int y = 0; y < h; y++)
		{
			for(int x = 0; x < w; x++)
			{
				static if(arr)
					auto z = data[y * w + x];
				else
					auto z = data;

				LayoutInst.convert(&DataSink.Sink, "{:e6} ", cast(double)z);
			}
			DataSink ~= "\n";
		}

		DataSink ~= "e\ne\n";

		PlotRaw(ArgsSink[], DataSink[]);

		return this;
	}
}

/**
 * A 2D data plotter.
 */
class C2DPlot : CGNUPlot
{
	/**
	 * See_Also:
	 *     $(SYMLINK CGNUPlot.this, CGNUPlot.this)
	 */
	this()
	{
		PlotStyle = "lines";
		PlotCommand = "plot";
	}

	/**
	 * See_Also:
	 *     $(SYMLINK CGNUPlot.this, CGNUPlot.this)
	 */
	this(char[] term)
	{
		PlotStyle = "lines";
		PlotCommand = "plot";
		super(term);
	}
	
	/**
	 * Plot a histogram of some data.
	 *
	 * Params:
	 *     data = Array of data.
	 *     num_bins = Number of bins to use (by default it is 10)
	 *     label = Label text to use for this histogram.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	C2DPlot Histogram(Data_t)(Data_t data, size_t num_bins = 10, char[] label = "")
	{
		static assert(IsArray!(Data_t), "Can't make a histogram of something that isn't an array type");
		assert(num_bins > 0, "Must have at least 2 bins");
		
		auto min_val = data[0];
		auto max_val = data[0];
		
		for(size_t ii = 0; ii < data.length; ii++)
		{
			if(data[ii] < min_val)
				min_val = data[ii];
			if(data[ii] > max_val)
				max_val = data[ii];
		}
		
		auto bins = new size_t[](num_bins);
		auto cats = new typeof(min_val)[](num_bins);
		
		foreach(idx, ref x; cats)
			x = idx * (max_val - min_val) / (num_bins - 1) + min_val;
		
		size_t max_bin = 0;
		
		if(max_val == min_val)
		{
			bins[$/2] = data.length;
			max_bin = data.length;
		}
		else
		{
			for(size_t ii = 0; ii < data.length; ii++)
			{
				auto idx = cast(size_t)(floor((data[ii] - min_val) * (num_bins - 1) / (max_val - min_val)));
				bins[idx]++;
				if(bins[idx] > max_bin)
					max_bin = bins[idx];
			}
		}
		
		YRange = [0, max_bin + 1];
		if(PlotStyle == "boxes")
			Command(`set style fill solid border rgbcolor "black"`);
		return Plot(cats, bins, label);
	}

	/**
	 * Plot a pair of arrays. Arrays must have the same size.
	 *
	 * Params:
	 *     X = Array of X coordinate data or a numerical constant.
	 *     Y = Array of Y coordinate data or a numerical constant.
	 *     label = Label text to use for this curve.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	C2DPlot Plot(X_t, Y_t)(X_t X, Y_t Y, char[] label = "")
	{
		const x_arr = IsArray!(X_t);
		const y_arr = IsArray!(Y_t);
		
		size_t len;
		
		static if(x_arr && y_arr)
			assert(X.length == Y.length, "Arrays must be of equal length to plot.");
		
		static if(x_arr)
			len = X.length;
		else static if(y_arr)
			len = Y.length;
		else
			len = 1;

		ArgsSink.Size = 0;
		DataSink.Size = 0;
		DataSink.Reserve(len * 15);

		ArgsSink ~= `"-"`;
		ArgsSink ~= ` title "` ~ label ~ `"`;
		ArgsSink ~= " with " ~ PlotStyle;
		if(PlotColor.length)
			ArgsSink ~= ` lc rgb "` ~ PlotColor ~ `"`;
		ArgsSink ~= ` lw ` ~ PlotThickness;
		if(StyleHasPoints && PlotPointType.length)
			ArgsSink ~= ` pt ` ~ PlotPointType;

		for(size_t ii = 0; ii < len; ii++)
		{
			static if(x_arr)
				auto x = X[ii];
			else
				auto x = X;

			static if(y_arr)
				auto y = Y[ii];
			else
				auto y = Y;

			LayoutInst.convert(&DataSink.Sink, "{:e6}\t{:e6}\n", cast(double)x, cast(double)y);
		}
		DataSink ~= "e\n";

		PlotRaw(ArgsSink[], DataSink[]);

		return this;
	}

	/**
	 * See_Also:
	 *     $(SYMLINK CGNUPlot.Style, CGNUPlot.Style)
	 */
	C2DPlot Style(char[] style)
	{
		super.Style(style);
		StyleHasPoints = PlotStyle.length != PlotStyle.find("points");

		return this;
	}

	/**
	 * Set the point type to use if plotting points. This differs from
	 * terminal to terminal, so experiment to find something good.
	 *
	 * Params:
	 *     type = Point type. Pass -1 to reset to the default point type.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	C2DPlot PointType(int type)
	{
		if(type < 0)
			PlotPointType = "";
		else
			PlotPointType = Format("{}", type);

		return this;
	}

	/**
	 * Set the thickness of points/lines for subsequent plot commands.
	 *
	 * Params:
	 *     thickness = Thickness of the point/lines.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	C2DPlot Thickness(float thickness)
	{
		assert(thickness >= 0);

		PlotThickness = Format("{}", thickness);

		return this;
	}

	/**
	 * Set the color of points/lines for subsequent plot commands.
	 *
	 * Params:
	 *     color = Triplet of values specifying the red, green and blue components
	 *             of the color. Each component ranges between 0 and 255.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	C2DPlot Color(int[3] color...)
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

/**
 * Base class for all plot types.
 *
 * This class is not terribly useful on its own, although you can use it as a
 * direct interface to gnuplot. It also contains functions that are relevant to
 * all plot types. 
 */
class CGNUPlot
{
	/**
	 * See_Also:
	 *     $(SYMLINK CGNUPlot.opCall, opCall)
	 */
	alias opCall Command;

	/**
	 * Create a new plot instance using the default terminal.
	 */
	this()
	{
		GNUPlot = new Process(true, "gnuplot -persist");
		GNUPlot.execute();
		LayoutInst = new typeof(LayoutInst)();
	}

	/**
	 * Create a new plot instance while specifying a different terminal type.
	 *
	 * Params:
	 *     term = Terminal name. Notable options include: wxt, svg, png, pdfcairo, postscript.
	 */
	this(char[] term)
	{
		this();
		Terminal = term;
	}

	/**
	 * Send a command directly to gnuplot.
	 *
	 * Params:
	 *     command = Command to send to gnuplot.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
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

	/**
	 * Returns errors, if any, that gnuplot returned. This uses a somewhat hacky
	 * method, requiring a timeout value. The default one should suffice. If you
	 * think your errors are getting cut off, try increasing it.
	 * 
	 * Only works on Linux.
	 *
	 * Params:
	 *     timeout = Number of milliseconds to wait for gnuplot to respond.
	 *
	 * Returns:
	 *     A string containing the errors.
	 */
	char[] GetErrors(int timeout = 100)
	{
		version(linux)
		{
			char[] ret;

			pollfd fd;
			fd.fd = GNUPlot.stderr.fileHandle;
			fd.events = POLLIN;

			while(poll(&fd, 1, timeout) > 0)
			{
				char[1024] buf;
				int len = GNUPlot.stderr.read(buf);
				if(len > 0)
					ret ~= buf[0..len];
			}

			return ret;
		}
		else
			return "";
	}

	/**
	 * Plots a string expression, with some data after it. This method is used
	 * by all other plot classes to do their plotting, by passing appropriate
	 * argumets. Can be useful if you want to plot a function and not data:
	 *
	 * ---
	 * plot.PlotRaw("x*x");
	 * ---
	 *
	 * Params:
	 *     args = Arguments to the current plot command.
	 *     data = Data for the current plot command. This controller uses the
	 *            inline data entry, so the format needs to be what that method
	 *            expects.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	CGNUPlot PlotRaw(char[] args, char[] data = null)
	{
		if(Holding && PlotArgs.length != 0)
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

		if(!Holding)
			Flush();

		return this;
	}

	/**
	 * If plotting is held, this plots the commands that were issued earlier.
	 * It does not disable the hold.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	CGNUPlot Flush()
	{
		Command(PlotCommand ~ " " ~ PlotArgs);
		Command(PlotData);

		PlotArgs.length = 0;
		PlotData.length = 0;

		return this;
	}

	/**
	 * Activates plot holding. While plotting is held, successive plot commands
	 * will be drawn on the same axes. Disable holding or call Flush to plot
	 * the commands.
	 *
	 * Params:
	 *     hold = Specifies whether to start or end holding.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	CGNUPlot Hold(bool hold)
	{
		Holding = hold;
		if(!Holding)
			Flush();

		return this;
	}

	/**
	 * Quits the gnuplot process. Call this command when you are done with the
	 * plot.
	 */
	void Quit()
	{
		Command("quit");
		GNUPlot.kill();
	}

	/**
	 * Refreshes the plot. Usually you don't need to call this command.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	CGNUPlot Refresh()
	{
		return Command("refresh");
	}

	/**
	 * Set the label for the X axis.
	 *
	 * Params:
	 *     label = Label text.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	CGNUPlot XLabel(char[] label)
	{
		return Command(`set xlabel "` ~ label ~ `"`);
	}

	/**
	 * Set the label for the Y axis.
	 *
	 * Params:
	 *     label = Label text.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	CGNUPlot YLabel(char[] label)
	{
		return Command(`set ylabel "` ~ label ~ `"`);
	}

	/**
	 * Set the range of the X axis.
	 *
	 * Params:
	 *     range = An array of two doubles specifying the minimum and the maximum.
	 *             Pass $(DIL_KW null) to make the axis auto-scale.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	CGNUPlot XRange(double[] range)
	{
		if(range !is null)
		{
			assert(range.length == 2);
			return Command(Format("set xrange [{:e6}:{:e6}]", range[0], range[1]));
		}
		else
			return Command("set xrange [*:*]");
	}

	/**
	 * Set the range of the Y axis.
	 *
	 * Params:
	 *     range = An array of two doubles specifying the minimum and the maximum.
	 *             Pass $(DIL_KW null) to make the axis auto-scale.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	CGNUPlot YRange(double[] range)
	{
		if(range !is null)
		{
			assert(range.length == 2);
			return Command(Format("set yrange [{:e6}:{:e6}]", range[0], range[1]));
		}
		else
			return Command("set yrange [*:*]");
	}

	/**
	 * Enable logarithmic scale for the X axis. Keep in mind that the minimum and
	 * maximum ranges need to be positive for this to work.
	 *
	 * Params:
	 *     use_log = Whether or not to actually set the logarithmic scale.
	 *     base = Base used for the logarithmic scale.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	CGNUPlot XLogScale(bool use_log = true, int base = 10)
	{
		if(use_log)
			return Command(Format("set logscale x {}", base));
		else
			return Command("unset logscale x");
	}

	/**
	 * Enable logarithmic scale for the Y axis. Keep in mind that the minimum and
	 * maximum ranges need to be positive for this to work.
	 *
	 * Params:
	 *     use_log = Whether or not to actually set the logarithmic scale.
	 *     base = Base used for the logarithmic scale.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	CGNUPlot YLogScale(bool use_log = true, int base = 10)
	{
		if(use_log)
			return Command(Format("set logscale y {}", base));
		else
			return Command("unset logscale y");
	}

	/**
	 * Set the title of this plot.
	 *
	 * Params:
	 *     title = Title text.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	CGNUPlot Title(char[] title)
	{
		return Command(`set title "` ~ title ~ `"`);
	}

	/**
	 * Set the style of this plot. Any style used by gnuplot is accetable here. $(P)
	 *
	 * Here are some commonly used plot styles. $(P)
	 *
	 * For 2D and 3D plots.$(P)
	 *     $(UL lines)
	 *     $(UL points)
	 *     $(UL linespoints)
	 * $(P)
	 * For 3D plots only:$(P)
	 *     $(UL image - Image plotting)
	 *     $(UL pm3d - Surface plotting)
	 *
	 * Params:
	 *     title = Title text.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	CGNUPlot Style(char[] style)
	{
		PlotStyle = style;

		return this;
	}

	/**
	 * Set the aspect ratio of the plot. Only works with 2D plots (or image 3D plots).
	 *
	 * Params:
	 *     ratio = Aspect ratio to use (height / width).
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	CGNUPlot AspectRatio(double ratio)
	{
		return Command(Format("set size ratio {}", ratio));
	}

	/**
	 * If you set a terminal that can output files, use this function to set the filename
	 * of the resultant file.
	 *
	 * Params:
	 *     filename = Filename text.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	CGNUPlot OutputFile(char[] filename)
	{
		return Command(Format(`set output "{}"`, filename));
	}
	
	/**
	 * Sets a terminal type, allowing, for example, output to a file.
	 *
	 * Params:
	 *     term = Terminal name. Notable options include: wxt, svg, png, pdfcairo, postscript.
	 */
	CGNUPlot Terminal(char[] term)
	{
		return Command("set term " ~ term);
	}
private:
	char[] PlotStyle = "lines";

	bool Holding = false;
	char[] PlotCommand = "plot";
	char[] PlotArgs;
	char[] PlotData;

	Process GNUPlot;
	STextSink!(char) ArgsSink;
	STextSink!(char) DataSink;
	Layout!(char) LayoutInst;
}
