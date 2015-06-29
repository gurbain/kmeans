/**
 * Parallel K-Means Clustering
 * 
 * @brief k-means clustering implementation enabling parallel 
 *        computing with OMP and CUDA to boost performances
 * @author Gabriel Urbain
 * @date 23/06/2015
 * @copyright 2015 UMONS. All rights reserved.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <getopt.h>
#include <math.h>

int      _debug;
#include "kmeans.h"

void kmeans (float** objects, float** centroids, int* membership, int numobj,
				int numcoord, int numcluster, int pmethod, int imethod,
				int split, int verbose, int save, char* filename)
{
	float **clustersInit, **clusters, **objectsIter;
	double timing, io_timing, clustering_timing;
	int  i, j, loop_iterations, splitNumber, iteration, lastObjsIteration;
	int *membershipIteration;
	float threshold = DELTA_THRESHOLD;
	
	if (verbose > 1)
		_debug = 1;
    if (numcluster <= 1)
		err("[pkmean] The number of clusters should be larger than 1");
	if (numobj < 1)
		err("[pkmean] The number of input points should be greater than 0");
	if (numcoord < 1)
		err("[pkmean] The number of coordinates should be greater than 0");
		

    if (verbose > 0) io_timing = wtime();

    /* init membership */
    membership = (int*) malloc(numobj * sizeof(int));
    assert(membership != NULL);
    for (i=0; i<numobj; i++) membership[i] = -1;
	
	/* initialize some other algorithm variables */
	int numObjsIteration = numobj / splitNumber;
	malloc2D(objects, numObjsIteration, numcoord, float);
    assert(objects != NULL);
	malloc2D(clustersInit, numcluster, numcoord, float);
    assert(clustersInit != NULL);
	membershipIteration = (int*) malloc(numObjsIteration * sizeof(int));
    assert(membershipIteration != NULL);

    /* start the timer for the core computation */
	if (verbose > 0) {
        timing            = wtime();
        io_timing         = timing - io_timing;
        clustering_timing = timing;
    }
		
	/* initialize the cluster vector */
	if (imethod == 1)
		cuda_kpp_init(objects, clustersInit, membership, numObjsIteration, numcoord, numcluster);
	else
		for (i=0; i<numcluster; i++)
			for (j=0; j<numcoord; j++)
				clustersInit[i][j] = objects[rand()%numObjsIteration][rand()%numcoord];
	if (imethod > 1)
		printf("[pkmean] This initialization method does not exist. Using random init");

 	/* data splitting to accelerate the process and minimize memory usage ---*/
 	iteration = 0;
 	while ( (iteration * numObjsIteration) < (numobj - numObjsIteration) ) {
 		if (verbose > 0) printf ("\n[cuda kmean] data block %i - number of objects %i\n", 
 				iteration + 1, numObjsIteration);
 		
 		// read data to clusterize
		memcpy(&objectsIter[0][0], &objects[iteration * numObjsIteration][0],
				numObjsIteration * numcoord * sizeof(float));
 		
 		// do clusterisation
 		clusters = cuda_kmeans(objectsIter, numcoord, numObjsIteration, numcluster,
 				clustersInit, threshold, membershipIteration, &loop_iterations);
 		
 		// keep the results
 		memcpy(&membership[iteration * numObjsIteration], &membershipIteration[0],
 				numObjsIteration * sizeof(int));
 		clustersInit = clusters;
 		
		// save in case of interruption
		if (save > 2) {
			char  tmpFilename[512];
			sprintf(tmpFilename, "%s.tmp-%i", filename, iteration+1);
			file_write(tmpFilename, numcluster, numobj, numcoord, clusters,
				membership);
		}
		
 		iteration++;
 	};
	
	/* last iteration -----------------------------------------------------*/
	lastObjsIteration = numobj - numObjsIteration * iteration;
	if (verbose > 0) printf ("\n[cuda kmean] data block %i - number of objects %i\n", 
				iteration + 1, lastObjsIteration);
	
	memcpy(&objectsIter[0][0], &objects[iteration * numObjsIteration][0],
				lastObjsIteration * numcoord * sizeof(float));
	clusters = cuda_kmeans(objectsIter, numcoord, lastObjsIteration, numcluster,
			clustersInit, threshold, membershipIteration, &loop_iterations);
	memcpy(&membership[iteration * numObjsIteration], &membershipIteration[0],
			lastObjsIteration * sizeof(int));
	
	
	/* restart io timer ----------------------------------------------------*/
	 if (verbose > 0) {
        timing            = wtime();
        clustering_timing = timing - clustering_timing;
    }

	/* free memory part 1 --------------------------------------------------*/
	free(objects);
	free(clustersInit);
	free(membershipIteration);

    /* output: the coordinates of the cluster centres ----------------------*/
    if (save > 1) file_write(filename, numcluster, numobj, numcoord, clusters,
               membership);
	
	/*---- output performance numbers --------------------------------------*/
    if (verbose > 0) {
        io_timing += wtime() - timing;
        printf("\n[cuda kmean] Performances results for cuda k-mean\n");

		printf("------------------------------------------\n");
        printf("input file:     %s\n", filename);
        printf("numobj       = %d\n", numobj);
        printf("numcoord     = %d\n", numcoord);
        printf("numcluster   = %d\n", numcluster);
        printf("threshold     = %.4f\n", threshold);
		printf("number of blocks    = %d\n", splitNumber);
        printf("loop iterations for last block    = %d\n\n", loop_iterations);

        printf("I/O time           = %10.4f sec\n", io_timing);
        printf("computation timing = %10.4f sec\n", clustering_timing);
		printf("------------------------------------------\n\n");
    }
    
	/* display results if needed --------------------------------------------*/
	if (save > 1) {
		float* xObj = (float*)malloc(numobj * sizeof(float));
		float* yObj = (float*)malloc(numobj * sizeof(float));
		float* xClu = (float*)malloc(numcluster * sizeof(float));
		float* yClu = (float*)malloc(numcluster * sizeof(float));
		for (i=0; i<numcluster; i++) {
			xClu[i] = clusters[i][0];
			yClu[i] = clusters[i][1];
		}
		for(i=0; i<numobj; i++) {
			xObj[i] = objects[i][0];
			yObj[i] = objects[i][1];
		}
		pdf_kmean(xObj, yObj, numobj, xClu, yClu, numcluster, membership);
		free(xObj);
		free(yObj);
		free(xClu);
		free(yClu);
		free(objects);
	}
	
	/* free memory part 2 */
	free(clusters);
	free(membership);

    return;
}
