module example;

import gnuplot;
import tango.math.Math;

void main()
{
	auto X = new double[](1000);
	auto Y1 = new double[](1000);
	auto Y2 = new double[](1000);
	
	foreach(ii, ref x; X)
	{
		x = -5 + ii * 10.0 / X.length;
		Y1[ii] = sin(x);
		Y2[ii] = x * x;
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
	
	auto matrix = new double[](10*10);
	for(int y = 0; y < 10; y++)
	{
		for(int x = 0; x < 10; x++)
		{
			matrix[y * 10 + x] = cos(x) * sin(y);
		}
	}
	
	/* An image plot */
	auto plot4 = new C3DPlot;
	with(plot4)
	{
		Title = "Image plotting";
		Plot(matrix, 10, 10, "cos(x) * sin(y)");
	}
	
	/* A surface plot */
	auto plot5 = new C3DPlot;
	with(plot5)
	{
		Title = "Image plotting";
		Style = "pm3d";
		View = [45, 45];
		Plot(matrix, 10, 10, "cos(x) * sin(y)");
	}
}
