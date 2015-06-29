/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
/*   File:         seq_main.c   (an sequential version)                      */
/*   Description:  This program shows an example on how to call a subroutine */
/*                 that implements a simple k-means clustering algorithm     */
/*                 based on Euclid distance.                                 */
/*   Input file format:                                                      */
/*                 ascii  file: each line contains 1 data object             */
/*                 binary file: first 4-byte integer is the number of data   */
/*                 objects and 2nd integer is the no. of features (or        */
/*                 coordinates) of each object                               */
/*                                                                           */
/*   Author:  Wei-keng Liao                                                  */
/*            ECE Department Northwestern University                         */
/*            email: wkliao@ece.northwestern.edu                             */
/*   Copyright, 2005, Wei-keng Liao                                          */
/*                                                                           */
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

// Copyright (c) 2005 Wei-keng Liao
// Copyright (c) 2011 Serban Giuroiu
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

// -----------------------------------------------------------------------------

#include <stdio.h>
#include <stdlib.h>
#include <string.h>     /* strtok() */
#include <sys/types.h>  /* open() */
#include <sys/stat.h>
#include <fcntl.h>
#include <getopt.h>

int      _debug;
#include "kmeans.h"

/*---< usage() >------------------------------------------------------------*/
static void usage(char *argv0, float threshold) {
    char *help =
        "Usage: %s [switches] -i filename -n num_clusters\n"
        "       -i filename    : file containing data to be clustered\n"
        "       -b             : input file is in binary format (default no)\n"
        "       -n num_clusters: number of clusters (K must > 1)\n"
        "       -t threshold   : threshold value (default %.4f)\n"
		"       -s splitNumber : split the data into s block (default 1)\n"
		"       -g             : display clustered data graph (default no)\n"
        "       -o             : output timing results (default no)\n"
        "       -d             : enable debug mode\n";
    fprintf(stderr, help, argv0, threshold);
    exit(-1);
}

/*---< main() >-------------------------------------------------------------*/
int main(int argc, char **argv) {
           int     opt;
    extern char   *optarg;
    extern int     optind;
           int     i, j;
           int     isBinaryFile, is_output_timing;
		   int     graph;

           int     numClusters, numCoords, numObjs;
           int    *membership;    /* [numObjs] */
           char   *filename;
           float **objects;
           float **clusters;      /* [numClusters][numCoords] cluster center */
           float   threshold;
           double  timing, io_timing, clustering_timing;
           int     loop_iterations;
		   
		   int     splitNumber;
		   int     iteration;
		   float **clustersInit;
		   int    *membershipIteration;
		   int     lastObjsIteration;

    /* some default values */
    _debug           = 0;
	graph			 = 0;
    threshold        = 0.001;
	splitNumber		 = 1;
    numClusters      = 0;
    isBinaryFile     = 0;
    is_output_timing = 0;
    filename         = NULL;

    while ( (opt=getopt(argc,argv,"p:i:l:n:s:t:abdgo"))!= EOF) {
        switch (opt) {
            case 'i': filename=optarg;
                      break;
            case 'b': isBinaryFile = 1;
                      break;
            case 't': threshold = atof(optarg);
                      break;
			case 's': splitNumber = atoi(optarg);
					  break;
            case 'n': numClusters = atoi(optarg);
                      break;
            case 'o': is_output_timing = 1;
                      break;
            case 'd': _debug = 1;
                      break;
			case 'g': graph = 1;
					  break;
            case '?': usage(argv[0], threshold);
                      break;
            default: usage(argv[0], threshold);
                      break;
        }
    }

    if (filename == 0 || numClusters <= 1) usage(argv[0], threshold);

    if (is_output_timing) io_timing = wtime();

    /* read number of points from file -------------------------------------*/
    file_read_head(isBinaryFile, filename, &numObjs, &numCoords);

    /* membership: the cluster id for each data object */
    membership = (int*) malloc(numObjs * sizeof(int));
    assert(membership != NULL);
	
    /* initialize membership[] */
    for (i=0; i<numObjs; i++) membership[i] = -1;
	
	/* initialize some other algorithm variables */
	int numObjsIteration = numObjs / splitNumber;
	malloc2D(objects, numObjsIteration, numCoords, float);
    assert(objects != NULL);
	malloc2D(clustersInit, numClusters, numCoords, float);
    assert(clustersInit != NULL);
	membershipIteration = (int*) malloc(numObjsIteration * sizeof(int));
    assert(membershipIteration != NULL);

    /* start the timer for the core computation -----------------------------*/
	if (is_output_timing) {
        timing            = wtime();
        io_timing         = timing - io_timing;
        clustering_timing = timing;
    }
    
    /* initialize the cluster vector with random value ----------------------*/
	objects = file_read_block(isBinaryFile, filename, numObjsIteration, numCoords);
	for (i=0; i<numClusters; i++)
        for (j=0; j<numCoords; j++)
            clustersInit[i][j] = objects[rand()%numObjsIteration][rand()%numCoords];
	
	/* data splitting to accelerate the process and minimize memory usage ---*/
	iteration = 0;
	while ( (iteration * numObjsIteration) < (numObjs - numObjsIteration) ) {
		printf ("[seq kmean] data block %i - number of objects %i\n", 
				iteration + 1, numObjsIteration);
		
		// read data to clusterize
		if (iteration != 0)
			objects = file_read_block(isBinaryFile, filename, numObjsIteration, numCoords);
		if (objects == NULL)
			exit(1);
		//memcpy(&objects[0][0], &objects[iteration * numObjsIteration][0],
				//numObjsIteration * numCoords * sizeof(float));
		
	
		// do clusterisation
		clusters = seq_kmeans(objects, numCoords, numObjsIteration, numClusters,
				clustersInit, threshold, membershipIteration, &loop_iterations);
		
		// save the results
		memcpy(&membership[iteration * numObjsIteration], &membershipIteration[0],
				numObjsIteration * sizeof(int));
		clustersInit = clusters;
		
		iteration++;
	};
	
	/* last iteration -----------------------------------------------------*/
	lastObjsIteration = numObjs - numObjsIteration * iteration;
	printf ("[seq kmean] data block %i - number of objects %i\n", 
				iteration + 1, lastObjsIteration);
	if (iteration != 0)
		objects = file_read_block(isBinaryFile, filename, lastObjsIteration, numCoords);
	if (objects == NULL)
		exit(1);

	clusters = seq_kmeans(objects, numCoords, lastObjsIteration, numClusters,
			clustersInit, threshold, membershipIteration, &loop_iterations);
	memcpy(&membership[iteration * numObjsIteration], &membershipIteration[0],
			lastObjsIteration * sizeof(int));
	
	
	/* restart io timer ----------------------------------------------------*/
	if (is_output_timing) {
        timing            = wtime();
        clustering_timing = timing - clustering_timing;
    }

	/* free memory part 1 --------------------------------------------------*/
	file_read_close(isBinaryFile);
	free(objects[0]);
	free(objects);
	free(clustersInit[0]);
	free(clustersInit);
	free(membershipIteration);

    /* output: the coordinates of the cluster centres ----------------------*/
    file_write(filename, numClusters, numObjs, numCoords, clusters,
               membership);

	/*- wait for key to continue -------------------------------------------*/
	char buff;
	printf("\n[seq kmean] Process finished. Press ENTER to continue");
	scanf("%c", &buff);
	
	/*---- output performance numbers --------------------------------------*/
    if (is_output_timing) {
        io_timing += wtime() - timing;
        printf("\n[cuda kmean] Performances results for cuda k-mean\n");

		printf("------------------------------------------\n");
        printf("input file:     %s\n", filename);
        printf("numObjs       = %d\n", numObjs);
        printf("numCoords     = %d\n", numCoords);
        printf("numClusters   = %d\n", numClusters);
        printf("threshold     = %.4f\n", threshold);
		printf("number of blocks    = %d\n", splitNumber);
        printf("loop iterations for last block    = %d\n\n", loop_iterations);

        printf("I/O time           = %10.4f sec\n", io_timing);
        printf("computation timing = %10.4f sec\n", clustering_timing);
		printf("------------------------------------------\n\n");
    }
    
	/* display results if needed --------------------------------------------*/
	if (graph) {
		file_read_head(isBinaryFile, filename, &numObjs, &numCoords);
		objects = file_read_block(isBinaryFile, filename, numObjs, numCoords);
		file_read_close(isBinaryFile);
		float* xObj = (float*)malloc(numObjs * sizeof(float));
		float* yObj = (float*)malloc(numObjs * sizeof(float));
		float* xClu = (float*)malloc(numClusters * sizeof(float));
		float* yClu = (float*)malloc(numClusters * sizeof(float));
		for (i=0; i<numClusters; i++) {
			xClu[i] = clusters[i][0];
			yClu[i] = clusters[i][1];
		}
		for(i=0; i<numObjs; i++) {
			xObj[i] = objects[i][0];
			yObj[i] = objects[i][1];
		}
		pdf_kmean(xObj, yObj, numObjs, xClu, yClu, numClusters, membership);
		free(xObj);
		free(yObj);
		free(xClu);
		free(yClu);
		free(objects);
	}
	
	/* free memory part 2 */
	free(clusters);
	free(membership);

    return(0);
}

