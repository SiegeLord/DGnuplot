module example;

import gnuplot;
import tango.math.Math;
import tango.math.random.Random;
import tango.core.ArrayLiteral : AL = ArrayLiteral;
import tango.io.Console;

void main()
{
	auto X = new double[](100);
	auto Y1 = new double[](100);
	auto Y2 = new double[](100);

	foreach(ii, ref x; X)
	{
		x = -5 + ii * 10.0 / X.length;
		Y1[ii] = sin(x);
		Y2[ii] = x * x;
	}
	
	/* A histogram */
	auto hist1 = new C2DPlot;
	with(hist1)
	{
		auto data = new double[](1000);
		foreach(ii, ref d; data)
			d = rand.normal!(double);
		Title = "Sample Histogram";
		Style = "boxes";
		Histogram(data, 20);
	}
	
	/* Another histogram */
	auto hist2 = new C2DPlot;
	with(hist2)
	{
		Title = "Sample Histogram";
		Style = "boxes";
		Histogram([0, 0, 0, 1, 1, 1, 2, 2, 2, 2, 3, 3, 4, 4], 5);
	}

	/* A simple 2D plot */
	auto plot1 = new C2DPlot;
	with(plot1)
	{
		Title = "Sample 2D Plot";
		Hold = true;
		Plot(X, Y1, "sin(x)");
		Plot(X, Y2, "x^2");
		Hold = false;
	}

	/* A 2D plot with some extra options */
	auto plot2 = new C2DPlot;
	with(plot2)
	{
		Title = "Fancier 2D Plot";
		Hold = true;

		XRange = [-1, 1];
		YRange = [-2, 2];

		XLabel = "Abscissa";
		YLabel = "Ordinate";

		AspectRatio = 1;

		Style = "linespoints";
		Thickness = 2;
		PointType = 2;
		Color = [0, 0, 0];
		Plot(X, Y1, "sin(x)");

		Thickness = 1;
		PointType = 4;
		Style = "points";
		Color = [0, 255, 255];
		Plot(X, Y2, "x^2");

		Hold = false;
	}

	/* Raw gnuplot commands can be used too */
	auto plot3 = new C2DPlot;
	with(plot3)
	{
		Title = "Raw gnuplot commands.";

		XRange = [-1, 1];
		YRange = [-2, 2];

		PlotRaw(`x*x*x title "cubic"`);
		Command("set arrow from 0, 0 to 1, 1");
		Refresh();
	}

	auto matrix = new double[](50*50);
	for(int y = 0; y < 50; y++)
	{
		for(int x = 0; x < 50; x++)
		{
			matrix[y * 50 + x] = cos(cast(double)x / 5) * sin(cast(double)y / 5);
		}
	}

	/* An image plot */
	auto plot4 = new C3DPlot;
	with(plot4)
	{
		Title = "Image plotting";
		Palette(23,28,3);
		Plot(matrix, 50, 50, AL(0.0, 0.0), AL(0.0, 0.0), "cos(x) * sin(y)");
	}

	/* A surface plot */
	auto plot5 = new C3DPlot;
	with(plot5)
	{
		Title = "Surface plotting";
		Style = "pm3d";
		View = [45, 45];
		Palette([[0.0, 0.0, 0.0, 1.0], [0.5, 0.5, 0.5, 0.5], [1.0, 1.0, 0.0, 0.0]]);
		Plot(matrix, 50, 50, AL(0.0, 0.0), AL(0.0, 0.0), "cos(x) * sin(y)");
	}
	
	/* Linear X plot */
	auto plot6 = new C2DPlot;
	with(plot6)
	{
		Title = "Linear X";
		PlotLinearX(Y2, AL(0.0, 1.0), "sin(x)");
	}
	
	/* Plot with errors */
	auto plot7 = new C2DPlot;
	with(plot7)
	{
		Title = "Error bar plot";
		Style = "errorbars";
		Hold = true;
		Plot(X, Y1, 3, "sin(x)");
		Plot(X, Y2, Y1, Y2);
		Hold = false;
	}
	
	version(Windows)
	{
		/* Gnuplot needs the main process alive for the plots to remain */
		Cout("Press ENTER to quit...").newline;
		char[] ret;
		Cin.readln(ret);
	}
}
