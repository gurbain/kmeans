/**
 * Parallel K-Means Clustering
 * 
 * @brief k-means clustering implementation enabling parallel 
 *        computing with OMP and CUDA to boost performances
 * @author Gabriel Urbain
 * @date 23/06/2015
 * @copyright 2015 UMONS. All rights reserved.
 */

#ifndef _H_P_KMEANS
#define _H_P_KMEANS

#ifndef THREADS_PER_BLOCK
#define THREADS_PER_BLOCK 	512
#endif
#ifndef MAX_ITER
#define MAX_ITER 			50
#endif
#ifndef DELTA_THRESHOLD
#define DELTA_THRESHOLD 	0.001
#endif

#ifdef __cplusplus
extern "C" {
#endif
  float** cuda_kmeans(float**, int, int, int, float **, float, int*, int*);

  void cuda_kpp_init(float**, float**, int*, int, int, int);

  void kmeans (float** objects,		// tab of input data points [numobj][numcoord]
			float** centroids,		// tab of output centroids  [numcluster][numcoord]
			int* membership,		// tab of output memberships [numobj]
			int numobj,				// number of input data points
			int numcoord,			// number of point coordinates
			int numcluster,			// number of output centroids
			int pmethod,			// parrelization method
										// 0: classic sequential method
										// 1: CPU parallel method using OMP
										// 2: GPU parallel method using CUDA
			int imethod,			// centroids init method
										// 0: random
										// 1: k++ seeding [https://en.wikipedia.org/wiki/K-means%2B%2B]
			int split,			// number of blocks to split sequentially the objects data 
									// (the more blocks, the fastest but also the less accurate,
									// especially if the initial distribution is not random)
			int verbose,			// text stream to stdout
										// 0: no messages
										// 1: basic messages
										// 2: basic and debug messages
			int save,				// save results
										// 0: no file saved
										// 1: save centroids and membership 
										// 2: save centroids and membership and .eps graph
										// 3: save centroids and membership, .eps graph and temp files
			char* filename);
#ifdef __cplusplus
}
#endif

#endif