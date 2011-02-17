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

import tango.core.Array;

import tango.text.convert.Format;
import tango.text.convert.Layout;

import tango.stdc.posix.poll;

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
	 * Parameters:
	 *     label - Label text.
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
	 * Parameters:
	 *     range - An array of two doubles specifying the minimum and the maximum.
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
			Command(Format("set zrange [{}:{}]", range[0], range[1]));
		}
		else
			Command("set zrange [*:*]");

		return this;
	}

	/**
	 * Enable logarithmic scale for the Z axis. Keep in mind that the minimum and
	 * maximum ranges need to be positive for this to work.
	 *
	 * Parameters:
	 *     use_log - Whether or not to actually set the logarithmic scale.
	 *     base - Base used for the logarithmic scale.
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
	 * Parameters:
	 *     x_z_rot - Rotation around the x and the z axes, in degrees. Pass $(DIL_KW null)
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
	 * Parameters:
	 *     pal - Name of the palette.
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
	 * Parameters:
	 *     r_formula, g_formula, b_formula - Formula indexes.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	C3DPlot Palette(int r_formula, int g_formula, int b_formula)
	{
		Command("set palette rgbformulae" ~ Format(" {},{},{}", r_formula, g_formula, b_formula));

		return this;
	}

	/**
	 * Plot a rectangular matrix of values.
	 *
	 * Parameters:
	 *     data - Linear array to the data. Assumes row-major storage.
	 *     w - Width of the array.
	 *     h - Height of the array.
	 *     label - Label text to use for this surface.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	C3DPlot Plot(T)(T[] data, size_t w, size_t h, char[] label = "")
	{
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
				LayoutInst.convert(&DataSink.Sink, "{:e6} ", cast(double)data[y * w + x]);
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
	 * Plot a pair of arrays. Arrays must have the same size.
	 *
	 * Parameters:
	 *     X - Array of X coordinate data.
	 *     Y - Array of Y coordinate data.
	 *     label - Label text to use for this curve.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	C2DPlot Plot(T)(T[] X, T[] Y, char[] label = "")
	{
		assert(X.length == Y.length, "Arrays must be of equal length to plot.");

		ArgsSink.Size = 0;
		DataSink.Size = 0;
		DataSink.Reserve(X.length * 15);

		ArgsSink ~= `"-"`;
		ArgsSink ~= ` title "` ~ label ~ `"`;
		ArgsSink ~= " with " ~ PlotStyle;
		if(PlotColor.length)
			ArgsSink ~= ` lc rgb "` ~ PlotColor ~ `"`;
		ArgsSink ~= ` lw ` ~ PlotThickness;
		if(StyleHasPoints && PlotPointType.length)
			ArgsSink ~= ` pt ` ~ PlotPointType;

		foreach(ii, x; X)
		{
			auto y = Y[ii];
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
	 * Parameters:
	 *     type - Point type. Pass -1 to reset to the default point type.
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
	 * Parameters:
	 *     thickness - Thickness of the point/lines.
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
	 * Parameters:
	 *     color - Triplet of values specifying the red, green and blue components
	 *             of the color. Each component ranges between 0 and 255.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
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

/**
 * Base class for all plot types.
 *
 * This class is not terribly useful on its own, although you can use it as a
 * direct interface to gnuplot. It also contains functions that are relevant to
 * all plot types. Note that most methods return a pointer to the instance, allowing
 * for method chaining:
 *
 * ---
 * (new CGNUPlot()).Title("Test Plot").XRange([-1, 1]).YRange([-1, 1]).PlotRaw("x*x*x");
 * ---
 *
 * I prefer this syntax, however:
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
	 * Parameters:
	 *     term - Terminal name. Notable options include: x11, svg, png, pdfcairo, postscript
	 */
	this(char[] term)
	{
		this();
		Command("set term " ~ term);
	}

	/**
	 * Send a command directly to gnuplot.
	 *
	 * Parameters:
	 *     command - Command to send to gnuplot.
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
	 * Parameters:
	 *     timeout - Number of milliseconds to wait for gnuplot to respond.
	 *
	 * Returns:
	 *     A string containing the errors.
	 */
	char[] GetErrors(int timeout = 100)
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

	/**
	 * Plots a string expression, with some data after it. This method is used
	 * by all other plot classes to do their plotting, by passing appropriate
	 * argumets. Can be useful if you want to plot a function and not data:
	 *
	 * ---
	 * plot.PlotRaw("x*x");
	 * ---
	 *
	 * Parameters:
	 *     args - Arguments to the current plot command.
	 *     data - Data for the current plot command. This controller uses the
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
	 * Parameters:
	 *     hold - Specifies whether to start or end holding.
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
	 * Parameters:
	 *     label - Label text.
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
	 * Parameters:
	 *     label - Label text.
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
	 * Parameters:
	 *     range - An array of two doubles specifying the minimum and the maximum.
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
			return Command(Format("set xrange [{}:{}]", range[0], range[1]));
		}
		else
			return Command("set xrange [*:*]");
	}

	/**
	 * Set the range of the Y axis.
	 *
	 * Parameters:
	 *     range - An array of two doubles specifying the minimum and the maximum.
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
			return Command(Format("set yrange [{}:{}]", range[0], range[1]));
		}
		else
			return Command("set yrange [*:*]");
	}

	/**
	 * Enable logarithmic scale for the X axis. Keep in mind that the minimum and
	 * maximum ranges need to be positive for this to work.
	 *
	 * Parameters:
	 *     use_log - Whether or not to actually set the logarithmic scale.
	 *     base - Base used for the logarithmic scale.
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
	 * Parameters:
	 *     use_log - Whether or not to actually set the logarithmic scale.
	 *     base - Base used for the logarithmic scale.
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
	 * Parameters:
	 *     title - Title text.
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
	 *     $(UL image - Image plotting.)
	 *     $(UL pm3d - Surface plotting.)
	 *
	 * Parameters:
	 *     title - Title text.
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
	 * Parameters:
	 *     ratio - Aspect ratio to use (height / width).
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
	 * Parameters:
	 *     filename - Filename text.
	 *
	 * Returns:
	 *     Reference to this instance.
	 */
	CGNUPlot OutputFile(char[] filename)
	{
		return Command(Format(`set output "{}"`, filename));
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
