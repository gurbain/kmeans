/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
/*   File:         cuda_kmeans.cu  (CUDA version)                            */
/*   Description:  Implementation of simple k-means clustering algorithm     */
/*                 This program takes an array of N data objects, each with  */
/*                 M coordinates and performs a k-means clustering given a   */
/*                 user-provided value of the number of clusters (K). The    */
/*                 clustering results are saved in 2 arrays:                 */
/*                 1. a returned array of size [K][N] indicating the center  */
/*                    coordinates of K clusters                              */
/*                 2. membership[N] stores the cluster center ids, each      */
/*                    corresponding to the cluster a data object is assigned */
/*                                                                           */
/*   Author:  Wei-keng Liao                                                  */
/*            ECE Department, Northwestern University                        */
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

#include "kmeans.h"

#define THREADS_PER_BLOCK 512
#define MAX_ITER 50


/*----< euclid_dist_2() >----------------------------------------------------*/
/* square of Euclid distance between two multi-dimensional points            */
__host__ __device__ inline static
float euclid_dist_2(int    numCoords,
                    int    numObjs,
                    int    numClusters,
                    float *objects,     // [numCoords][numObjs]
                    float *clusters,    // [numCoords][numClusters]
                    int    objectId,
                    int    clusterId)
{
    int i;
    float ans=0.0;

    for (i = 0; i < numCoords; i++) {
        ans += (objects[numObjs * i + objectId] - clusters[numClusters * i + clusterId]) *
               (objects[numObjs * i + objectId] - clusters[numClusters * i + clusterId]);
    }

    return(ans);
}

/*----< find_nearest_cluster() >---------------------------------------------*/
__global__ static
void find_nearest_cluster(int numCoords,
                          int numObjs,
                          int numClusters,
						  float *distance,
                          float *objects,           //  [numCoords][numObjs]
                          float *deviceClusters,    //  [numCoords][numClusters]
                          int *membership,          //  [numObjs]
                          int *deviceDelta)
{
    extern __shared__ char sharedMemory[];

    //  The type chosen for membershipChanged must be large enough to support
    //  reductions! There are blockDim.x elements, one for each thread in the
    //  block. See numThreadsPerClusterBlock in cuda_kmeans().
    unsigned char *membershipChanged = (unsigned char *)sharedMemory;
#if BLOCK_SHARED_MEM_OPTIMIZATION
    float *clusters = (float *)(sharedMemory + blockDim.x);
#else
    float *clusters = deviceClusters;
#endif

    membershipChanged[threadIdx.x] = 0;

#if BLOCK_SHARED_MEM_OPTIMIZATION
    //  BEWARE: We can overrun our shared memory here if there are too many
    //  clusters or too many coordinates! For reference, a Tesla C1060 has 16
    //  KiB of shared memory per block, and a GeForce GTX 480 has 48 KiB of
    //  shared memory per block.
    for (int i = threadIdx.x; i < numClusters; i += blockDim.x) {
        for (int j = 0; j < numCoords; j++) {
            clusters[numClusters * j + i] = deviceClusters[numClusters * j + i];
        }
    }
    __syncthreads();
#endif

    int objectId = blockDim.x * blockIdx.x + threadIdx.x;
    if (objectId < numObjs) {
        int   index, i;
        float dist, min_dist;
        /* find the cluster id that has min distance to object */
        index    = 0;
        min_dist = euclid_dist_2(numCoords, numObjs, numClusters,
                                 objects, clusters, objectId, 0);

        for (i=1; i<numClusters; i++) {
            dist = euclid_dist_2(numCoords, numObjs, numClusters,
                                 objects, clusters, objectId, i);
            /* no need square root */
            if (dist < min_dist) { /* find the min and its array index */
                min_dist = dist;
                index    = i;
            }
        }
        distance[objectId] = min_dist;

        if (membership[objectId] != index) {
            membershipChanged[threadIdx.x] = 1;
        }
        /* assign the membership to object objectId */
        membership[objectId] = index;
        __syncthreads();    //  For membershipChanged[]
    }
	
	// Compute delta
	if( 0 == threadIdx.x ) {
		int sum = 0;
		for( int i = 0; i < THREADS_PER_BLOCK; i++ ) {
			if (i + blockIdx.x*blockDim.x < numObjs)
				sum += membershipChanged[i];
		}
		atomicAdd( &deviceDelta[0] , sum );
	}
}

/*----< cuda_kmeans() >-------------------------------------------------------*/
//
//  ----------------------------------------
//  DATA LAYOUT
//
//  objects         [numObjs][numCoords]
//  clusters        [numClusters][numCoords]
//  dimObjects      [numCoords][numObjs]
//  dimClusters     [numCoords][numClusters]
//  newClusters     [numCoords][numClusters]
//  deviceObjects   [numCoords][numObjs]
//  deviceClusters  [numCoords][numClusters]
//  ----------------------------------------
//
/* return an array of cluster centers of size [numClusters][numCoords]       */
float** cuda_kmeans(float **objects,      /* in: [numObjs][numCoords] */
                   int     numCoords,    /* no. features */
                   int     numObjs,      /* no. objects */
                   int     numClusters,  /* no. clusters */
				   float **clustersInit, /* init value for cluster */
                   float   threshold,    /* % objects change membership */
                   int    *membership,   /* out: [numObjs] */
                   int    *loop_iterations)
{
    int      i, j, index, loop=0;
    int     *newClusterSize; /* [numClusters]: no. objects assigned in each
                                new cluster */
    int 	*d;
    float    delta;          /* % of objects change their clusters */
    float  **dimObjects;
    float  **clusters;       /* out: [numClusters][numCoords] */
    float  **dimClusters;
    float  **newClusters;    /* [numCoords][numClusters] */

    float *deviceObjects;
    float *deviceClusters;
    int *deviceMembership;
    int *deviceDelta;

    //  Copy objects given in [numObjs][numCoords] layout to new
    //  [numCoords][numObjs] layout
	if (_debug) printf("[cuda kmean] transposing objects matrix\n");
    malloc2D(dimObjects, numCoords, numObjs, float);
    for (i = 0; i < numCoords; i++) {
        for (j = 0; j < numObjs; j++) {
            dimObjects[i][j] = objects[j][i];
        }
    }

    /* pick numClusters elements of objects[] as initial cluster centers*/
	if (_debug) printf("[cuda kmean] reinitialising cluster matrix\n");
    malloc2D(dimClusters, numCoords, numClusters, float);
    for (i = 0; i < numCoords; i++)
        for (j = 0; j < numClusters; j++)
			dimClusters[i][j] = clustersInit[j][i];

    /* initialize membership[] */
	if (_debug) printf("[cuda kmean] initializing membership vector\n");
    for (i=0; i<numObjs; i++) membership[i] = -1;

    /* need to initialize newClusterSize and newClusters[0] to all 0 */
    newClusterSize = (int*) calloc(numClusters, sizeof(int));
    assert(newClusterSize != NULL);

    malloc2D(newClusters, numCoords, numClusters, float);
    memset(newClusters[0], 0, numCoords * numClusters * sizeof(float));
	
	d = (int *)malloc( sizeof( int ) );

    const unsigned int numClusterBlocks = numObjs / THREADS_PER_BLOCK + 1;
	
#if BLOCK_SHARED_MEM_OPTIMIZATION
    const unsigned int clusterBlockSharedDataSize =
        THREADS_PER_BLOCK * sizeof(unsigned char) +
        numClusters * numCoords * sizeof(float);

    cudaDeviceProp deviceProp;
    int deviceNum;
    cudaGetDevice(&deviceNum);
    cudaGetDeviceProperties(&deviceProp, deviceNum);

    if (clusterBlockSharedDataSize > deviceProp.sharedMemPerBlock) {
        err("WARNING: Your CUDA hardware has insufficient block shared memory. "
            "You need to recompile with BLOCK_SHARED_MEM_OPTIMIZATION=0. "
            "See the README for details.\n");
    }
#else
    const unsigned int clusterBlockSharedDataSize =
        THREADS_PER_BLOCK * sizeof(unsigned char);
#endif

	if (_debug) printf("[cuda kmean] CUDA memory allocation\n");
    checkCuda(cudaMalloc(&deviceObjects, numObjs*numCoords*sizeof(float)));
    checkCuda(cudaMalloc(&deviceClusters, numClusters*numCoords*sizeof(float)));
    checkCuda(cudaMalloc(&deviceMembership, numObjs*sizeof(int)));
    checkCuda(cudaMalloc(&deviceDelta, sizeof(int)));
    if (_debug)
		printf("[cuda kmean] distribution: %i blocks - %i threads\n", numClusterBlocks, THREADS_PER_BLOCK);
    checkCuda(cudaMemcpy(deviceObjects, dimObjects[0],
              numObjs*numCoords*sizeof(float), cudaMemcpyHostToDevice));
    checkCuda(cudaMemcpy(deviceMembership, membership,
              numObjs*sizeof(int), cudaMemcpyHostToDevice));
	
	/* initialize dist */
	float totalDistance = 0.0;
	float* dist = (float*) malloc(numObjs * sizeof(float));
	float* deviceDist;
	checkCuda(cudaMalloc(&deviceDist, numObjs*sizeof(float)));
	checkCuda(cudaMemcpy(deviceDist, dist, numObjs*sizeof(float), cudaMemcpyHostToDevice));
	
	if (_debug) printf("[cuda kmean] start iterative algorithm\n");
    do {
		
		for (i=0; i<numObjs; i++)
			dist[i] = 0.0;
        
		checkCuda(cudaMemcpy(deviceClusters, dimClusters[0],
                  numClusters*numCoords*sizeof(float), cudaMemcpyHostToDevice));

		d[0] = 0;
		checkCuda(cudaMemcpy(deviceDelta, d, sizeof(int), cudaMemcpyHostToDevice));

        find_nearest_cluster
            <<< numClusterBlocks, THREADS_PER_BLOCK, clusterBlockSharedDataSize >>>
            (numCoords, numObjs, numClusters, deviceDist,
             deviceObjects, deviceClusters, deviceMembership, deviceDelta);
        cudaDeviceSynchronize(); checkLastCudaError();

        checkCuda(cudaMemcpy(d, deviceDelta, sizeof(int), cudaMemcpyDeviceToHost));
        checkCuda(cudaMemcpy(membership, deviceMembership,
                  numObjs*sizeof(int), cudaMemcpyDeviceToHost));
		checkCuda(cudaMemcpy(dist, deviceDist,
                   numObjs*sizeof(float), cudaMemcpyDeviceToHost));
		
		delta = (float)d[0];
		delta /= numObjs;
		
        for (i=0; i<numObjs; i++) {
            /* find the array index of nestest cluster center */
            index = membership[i];

            /* update new cluster centers : sum of objects located within */
            newClusterSize[index]++;
            for (j=0; j<numCoords; j++)
                newClusters[j][index] += objects[i][j];
        }
        
        //  TODO: Flip the nesting order
        //  TODO: Change layout of newClusters to [numClusters][numCoords]
        /* average the sum and replace old cluster centers with newClusters */
        for (i=0; i<numClusters; i++) {
            for (j=0; j<numCoords; j++) {
                if (newClusterSize[i] > 0)
                    dimClusters[j][i] = newClusters[j][i] / newClusterSize[i];
                newClusters[j][i] = 0.0;   /* set back to 0 */
            }
            newClusterSize[i] = 0;   /* set back to 0 */
        }
		
        /* compute total distance and display results*/
		totalDistance = 0.0;
		for (i=0; i<numObjs; i++) {
// 			printf("d: %.2f\n", dist[i]);
			totalDistance += dist[i];
		}
		if (_debug) printf("Total distance = %f delta = %.3f\n", totalDistance, delta);
		
    } while (delta > threshold && loop++ < MAX_ITER);
	
    *loop_iterations = loop + 1;

    /* allocate a 2D space for returning variable clusters[] (coordinates
       of cluster centers) */
    malloc2D(clusters, numClusters, numCoords, float);
    for (i = 0; i < numClusters; i++) {
        for (j = 0; j < numCoords; j++) {
            clusters[i][j] = dimClusters[j][i];
        }
    }
    
    checkCuda(cudaFree(deviceObjects));
    checkCuda(cudaFree(deviceClusters));
    checkCuda(cudaFree(deviceMembership));
    checkCuda(cudaFree(deviceDelta));

    free(dimObjects[0]);
    free(dimObjects);
    free(dimClusters[0]);
    free(dimClusters);
    free(newClusters[0]);
    free(newClusters);
    free(newClusterSize);

    return clusters;
}

