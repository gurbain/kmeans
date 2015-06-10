#include <stdlib.h>
#include <graphics.h>
#include <X11/Xlib.h>

// FOR FUNCTION TESTS
// int main()
// {
// 	int nClusters = 50;
// 	int nObjects = 500;
// 	int i, j;
// 	float *xObjects, *yObjects, *xClusters, *yClusters;
// 	xObjects = (float*)malloc(nObjects * sizeof(float));
// 	yObjects = (float*)malloc(nObjects * sizeof(float));
// 	xClusters = (float*)malloc(nClusters * sizeof(float));
// 	yClusters = (float*)malloc(nClusters * sizeof(float));
// 	printf("Objects: ");
// 	for (i = 0; i < nObjects; i++) {
// 		xObjects[i] = (float)rand()/(float)(RAND_MAX/8);
// 		yObjects[i] = (float)rand()/(float)(RAND_MAX/30);
// 		printf("(%.2f;", xObjects[i]);
// 		printf("%.2f) ", yObjects[i]);
// 	}
// 	printf("\nClusters: ");
// 	for (i = 0; i < nClusters; i++) {
// 		xClusters[i] = (float)rand()/(float)(RAND_MAX/10);
// 		yClusters[i] = (float)rand()/(float)(RAND_MAX/40);
// 		printf("(%.2f;", xClusters[i]);
// 		printf("%.2f) ", yClusters[i]);
// 	}
// 	graph_kmean(xObjects, yObjects, nObjects, xClusters, yClusters, nClusters);
// }

int graph_kmean(float* xObjects, float* yObjects, int nObjects, float* xClusters, float* yClusters, int nClusters, int* membership, float totalDistance)
{
	const int MIN_X = 3, MIN_Y = 3, MAX_X = 637, MAX_Y = 477, RANGE_X = 634, RANGE_Y = 474;
	int i;
	
	// Find max and min coordinates
	float xMax = -1000000, xMin = 1000000, yMax = -1000000, yMin = 1000000;
	for (i = 0; i < nObjects; i++) {
		if (xObjects[i] > xMax)
			xMax = xObjects[i];
		if (xObjects[i] < xMin)
			xMin = xObjects[i];
		if (yObjects[i] > yMax)
			yMax = yObjects[i];
		if (yObjects[i] < yMin)
			yMin = yObjects[i];
	}
	for (i = 0; i < nClusters; i++) {
		if (xClusters[i] > xMax)
			xMax = xClusters[i];
		if (xClusters[i] < xMin)
			xMin = xClusters[i];
		if (yClusters[i] > yMax)
			yMax = yClusters[i];
		if (yClusters[i] < yMin)
			yMin = yClusters[i];
	}
	//printf("\nxMax: %.2f; yMax: %.2f; xMin: %.2f; yMin: %.2f", xMax, yMax, xMin, yMin);
	
	// Rescale
	float xRange = xMax - xMin;
	float yRange = yMax - yMin;
	//printf("\nObjects: ");
	for (i = 0; i < nObjects; i++) {
		xObjects[i] = MIN_X + (xObjects[i] - xMin) * RANGE_X / xRange;
		yObjects[i] = MIN_Y + (yObjects[i] - yMin) * RANGE_Y / yRange;
		//printf("(%.2f;", xObjects[i]);
		//printf("%.2f) ", yObjects[i]);
	}
	//printf("\nClusters: ");
	for (i = 0; i < nClusters; i++) {
		xClusters[i] = MIN_X + (xClusters[i] - xMin) * RANGE_X / xRange;
		yClusters[i] = MIN_Y + (yClusters[i] - yMin) * RANGE_Y / yRange;
		//printf("(%.2f;", xClusters[i]);
		//printf("%.2f) ", yClusters[i]);
	}
	//printf("\n");
	
	// Open window
	XInitThreads();
	int gd = DETECT, gm;
	initgraph(&gd, &gm, NULL);
	
	// Display points
	int j;
	for (i = 0; i < nObjects; i++) {
		j = membership[i]%15;
		if (j==0) {
			j=14;
		} else if (membership[i] == 0) {
			j=15;
		}
		setcolor(j);
		pieslice(xObjects[i], yObjects[i], 0, 360, 1);
	}
// 	for (i = 0; i < nClusters; i++){
// 		j = i%15;
// 		if (j==0)
// 			j=2;
// 		setcolor(j);
// 		pieslice(xClusters[i], yClusters[i], 0, 360, 3);
// 	}
	printf("\nTotal distance: %.2f", totalDistance);
	
	// Wait for any char as exit command 
	getch();
	closegraph();
	return 0;
}