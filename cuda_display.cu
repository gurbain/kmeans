#include <stdio.h>
#include <stdlib.h>
#include <math.h>
// #include <graphics.h>
// #include <X11/Xlib.h>

#	define W 400
#	define H 400

// FOR FUNCTION TESTS
// int main()
// {
// 	int nClusters = 50;
// 	int nObjects = 500;
// 	int i, j;
// 	float *xObjects, *yObjects, *xClusters, *yClusters;
//	int *membership;
// 	xObjects = (float*)malloc(nObjects * sizeof(float));
// 	yObjects = (float*)malloc(nObjects * sizeof(float));
// 	xClusters = (float*)malloc(nClusters * sizeof(float));
// 	yClusters = (float*)malloc(nClusters * sizeof(float));
//  membership = (int*)malloc(nObjects * sizeof(int));
// 	printf("Objects: ");
// 	for (i = 0; i < nObjects; i++) {
// 		xObjects[i] = (float)rand()/(float)(RAND_MAX/8);
// 		yObjects[i] = (float)rand()/(float)(RAND_MAX/30);
//		membership[i] = rand()/(RAND_MAX/nClusters);
// 		printf("(%.2f;", xObjects[i]);
// 		printf("%.2f;", yObjects[i]);
//		printf("%i) ", membership[i]);
// 	}
// 	printf("\nClusters: ");
// 	for (i = 0; i < nClusters; i++) {
// 		xClusters[i] = (float)rand()/(float)(RAND_MAX/10);
// 		yClusters[i] = (float)rand()/(float)(RAND_MAX/40);
// 		printf("(%.2f;", xClusters[i]);
// 		printf("%.2f) ", yClusters[i]);
// 	}
// 	graph_kmean(xObjects, yObjects, nObjects, xClusters, yClusters, nClusters, membership);
// }

void pdf_kmean(float* xObjects, float* yObjects, int nObjects, float* xClusters, float* yClusters, int nClusters, int* membership)
{
	int i, j;
	double min_x, max_x, min_y, max_y, scale, cx, cy;
	double *colors = (double*)malloc(sizeof(double) * nClusters * 3);
 
	// Open file
	FILE *fptr = fopen("results.eps", "w");
	if (fptr == NULL) {
		printf("[display] Cannot create results.pdf file!\n");
		return;
	}
	
	// Compute colors
	for (i = 0; i < nClusters; i++) {
		colors[3*i + 0] = (3 * (i + 1) % 11)/11.;
		colors[3*i + 1] = (7 * i % 11)/11.;
		colors[3*i + 2] = (9 * i % 11)/11.;
	}
 
	// Find max, min and range values
	max_x = max_y = -(min_x = min_y = HUGE_VAL);
	for (j = 0; j < nObjects; j++) {
		if (max_x < xObjects[j]) max_x = xObjects[j];
		if (min_x > xObjects[j]) min_x = xObjects[j];
		if (max_y < yObjects[j]) max_y = yObjects[j];
		if (min_y > yObjects[j]) min_y = yObjects[j];
	}
	scale = W / (max_x - min_x);
	if (scale > H / (max_y - min_y)) scale = H / (max_y - min_y);
	cx = (max_x + min_x) / 2;
	cy = (max_y + min_y) / 2;
	
	// Fill the PDF
	fprintf(fptr, "%%!PS-Adobe-3.0\n%%%%BoundingBox: -5 -5 %d %d\n", W + 10, H + 10);
	fprintf(fptr,  "/l {rlineto} def /m {rmoveto} def\n"
		"/c { .25 sub exch .25 sub exch .5 0 360 arc fill } def\n"
		"/s { moveto -2 0 m 2 2 l 2 -2 l -2 -2 l closepath "
		"	gsave 1 setgray fill grestore gsave 3 setlinewidth"
		" 1 setgray stroke grestore 0 setgray stroke }def\n"
	);
	for (i = 0; i < nClusters; i++) {
		fprintf(fptr, "%g %g %g setrgbcolor\n",
			colors[3*i], colors[3*i + 1], colors[3*i + 2]);
		for (j = 0; j < nObjects; j++) {
			if (membership[j] != i) continue;
			fprintf(fptr, "%.3f %.3f c\n",
				(xObjects[j] - cx) * scale + W / 2,
				(yObjects[j] - cy) * scale + H / 2);
		}
		fprintf(fptr, "\n0 setgray %g %g s\n",
			(xClusters[i] - cx) * scale + W / 2,
			(yClusters[i] - cy) * scale + H / 2);
	}
	fprintf(fptr, "\n%%%%EOF");
	fclose(fptr);
	free(colors);
}


void gui_kmean(float* xObjects, float* yObjects, int nObjects, float* xClusters, float* yClusters, int nClusters, int* membership)
{
// 	const int MIN_X = 3, MIN_Y = 3, RANGE_X = 634, RANGE_Y = 474; //, MAX_X = 637, MAX_Y = 477;
// 	int i;
// 	
// 	// Find max and min coordinates
// 	float xMax = -1000000, xMin = 1000000, yMax = -1000000, yMin = 1000000;
// 	for (i = 0; i < nObjects; i++) {
// 		if (xObjects[i] > xMax)
// 			xMax = xObjects[i];
// 		if (xObjects[i] < xMin)
// 			xMin = xObjects[i];
// 		if (yObjects[i] > yMax)
// 			yMax = yObjects[i];
// 		if (yObjects[i] < yMin)
// 			yMin = yObjects[i];
// 	}
// 	for (i = 0; i < nClusters; i++) {
// 		if (xClusters[i] > xMax)
// 			xMax = xClusters[i];
// 		if (xClusters[i] < xMin)
// 			xMin = xClusters[i];
// 		if (yClusters[i] > yMax)
// 			yMax = yClusters[i];
// 		if (yClusters[i] < yMin)
// 			yMin = yClusters[i];
// 	}
// 	
// 	// Rescale
// 	float xRange = xMax - xMin;
// 	float yRange = yMax - yMin;
// 	//printf("\nObjects: ");
// 	for (i = 0; i < nObjects; i++) {
// 		xObjects[i] = MIN_X + (xObjects[i] - xMin) * RANGE_X / xRange;
// 		yObjects[i] = MIN_Y + (yObjects[i] - yMin) * RANGE_Y / yRange;
// 		//printf("(%.2f;", xObjects[i]);
// 		//printf("%.2f) ", yObjects[i]);
// 	}
// 	//printf("\nClusters: ");
// 	for (i = 0; i < nClusters; i++) {
// 		xClusters[i] = MIN_X + (xClusters[i] - xMin) * RANGE_X / xRange;
// 		yClusters[i] = MIN_Y + (yClusters[i] - yMin) * RANGE_Y / yRange;
// 		//printf("(%.2f;", xClusters[i]);
// 		//printf("%.2f) ", yClusters[i]);
// 	}
// 	//printf("\n");
// 	
// 	// Open window
// 	XInitThreads();
// 	int gd = DETECT, gm;
// 	initgraph(&gd, &gm, NULL);
// 	
// 	// Display points
// 	int j;
// 	for (i = 0; i < nObjects; i++) {
// 		j = membership[i]%15;
// 		if (j==0) {
// 			j=14;
// 		} else if (membership[i] == 0) {
// 			j=15;
// 		}
// 		setcolor(j);
// 		pieslice(xObjects[i], yObjects[i], 0, 360, 1);
// 	}
// // 	for (i = 0; i < nClusters; i++){
// // 		j = i%15;
// // 		if (j==0)
// // 			j=2;
// // 		setcolor(j);
// // 		pieslice(xClusters[i], yClusters[i], 0, 360, 3);
// // 	}
// 	
// 	// Wait for any char as exit command 
// 	getch();
// 	closegraph();
	return;
}