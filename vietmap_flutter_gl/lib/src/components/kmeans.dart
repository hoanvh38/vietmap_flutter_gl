// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

/// This class describes a clustering.
class Clusters {
  Clusters(this.points, this.ignoredDims, this.clusters, this.means);

  /// The list of all points in the clusters.
  final List<List<double>> points;

  /// Dimensions of [points] that are ignored.
  final List<int> ignoredDims;

  /// For each point `points[i]`, `clusters[i]` gives the index of the cluster
  /// that `points[i]` is a member of. The mean of the cluster is given by
  /// `means[clusters[i]]`.
  final List<int> clusters;

  /// The means of the clusters.
  final List<List<double>> means;

  /// Convenience getter for the number of clusters.
  int get k => means.length;

  /// For each cluster, the list of points belonging to that cluster.
  ///
  /// `clusterPoints[i]` gives the list of points belonging to the cluster with
  /// mean `means[i]`.
  late final List<List<List<double>>> clusterPoints = (() {
    final cp = List<List<List<double>>>.generate(
      means.length,
      (int i) => <List<double>>[],
    );
    for (var i = 0; i < points.length; i++) {
      cp[clusters[i]].add(points[i]);
    }
    return cp;
  })();

  /// Sum of squared distances of samples to their closest cluster center.
  late final double inertia = (() {
    var sum = 0.0;
    for (var i = 0; i < points.length; i++) {
      sum += _distSquared(points[i], means[clusters[i]], ignoredDims);
    }
    return sum;
  })();

  /// Computes the average 'silhouette' over all points.
  ///
  /// The higher the silhouette the better the clustering.
  ///
  /// This uses an exact computation of the silhouette of each point as defined
  /// in https://en.wikipedia.org/wiki/Silhouette_(clustering).
  late final double exactSilhouette = (() {
    // For each point and each cluster calculate the mean squared distance of
    // the point to each point in the cluster.
    final meanClusterDist = List<List<double>>.generate(
      means.length,
      (int i) {
        return List<double>.filled(points.length, 0.0);
      },
    );
    for (var k = 0; k < means.length; k++) {
      for (var i = 0; i < points.length; i++) {
        var distSum = 0.0;
        for (var j = 0; j < clusterPoints[k].length; j++) {
          distSum += _distSquared(points[i], clusterPoints[k][j], ignoredDims);
        }
        meanClusterDist[k][i] = clusterPoints[k].length > 1
            ? distSum / (clusterPoints[k].length - 1).toDouble()
            : distSum;
      }
    }

    // For each point find the minimum mean squared distance to a neighbor
    // cluster.
    final minNeighborDist = List<double>.filled(
      points.length,
      0.0,
    );
    for (var i = 0; i < points.length; i++) {
      var min = double.maxFinite;
      for (var j = 0; j < means.length; j++) {
        if (j != clusters[i] && meanClusterDist[j][i] < min) {
          min = meanClusterDist[j][i];
        }
      }
      minNeighborDist[i] = min;
    }

    // Find the 'silhouette' of each point.
    final silhouettes = List<double>.filled(points.length, 0.0);
    for (var i = 0; i < points.length; i++) {
      final c = clusters[i];
      silhouettes[i] = clusterPoints[c].length > 1
          ? (minNeighborDist[i] - meanClusterDist[c][i]) /
              max(minNeighborDist[i], meanClusterDist[c][i])
          : 0.0;
    }

    // Return the average silhouette.
    var silhouetteSum = 0.0;
    for (var i = 0; i < points.length; i++) {
      silhouetteSum += silhouettes[i];
    }
    return silhouetteSum / points.length.toDouble();
  })();

  /// Computes an approximation of the average 'silhouette' over all points.
  ///
  /// The higher the silhouette the better the clustering.
  ///
  /// When needed in the silhouette computation, instead of calculating the
  /// average distance of each point to all points in a cluster, this
  /// approximation calculates the average distance to a random subset of at
  /// most 100 points in a cluster.
  ///
  /// See: https://en.wikipedia.org/wiki/Silhouette_(clustering).
  late final double silhouette = (() {
    final rng = Random(100);

    // For each point find the mean distance over all points in the nearest
    // neighbor cluster.
    final minNeighborDist = List<double>.filled(
      points.length,
      0.0,
    );
    for (var i = 0; i < points.length; i++) {
      var minDist = double.maxFinite;
      var minNeighborK = -1;
      for (var k = 0; k < means.length; k++) {
        if (clusters[i] == k) {
          continue;
        }
        final d = _distSquared(points[i], means[k], ignoredDims);
        if (d < minDist) {
          minDist = d;
          minNeighborK = k;
        }
      }
      // If the size of the cluster is over some threshold, then
      // sample the points isntead of summing all of them.
      final cluster = clusterPoints[minNeighborK];
      final neighborSize = cluster.length;
      if (neighborSize <= 100) {
        var sum = 0.0;
        for (var j = 0; j < cluster.length; j++) {
          sum += _distSquared(points[i], cluster[j], ignoredDims);
        }
        minNeighborDist[i] = sum / cluster.length.toDouble();
      } else {
        // 100 samples.
        var sum = 0.0;
        for (var j = 0; j < 100; j++) {
          final sample = rng.nextInt(neighborSize);
          sum += _distSquared(points[i], cluster[sample], ignoredDims);
        }
        minNeighborDist[i] = sum / 100.0;
      }
    }

    // For each point find the mean distance over all points in the same
    // cluster.
    final meanClusterDist = List<double>.filled(
      points.length,
      0.0,
    );
    for (var i = 0; i < points.length; i++) {
      // If the size of the cluster is over some threshold, then
      // sample the points isntead of summing all of them.
      final k = clusters[i];
      final clusterSize = clusterPoints[k].length;
      if (clusterSize <= 100) {
        var sum = 0.0;
        for (var j = 0; j < clusterPoints[k].length; j++) {
          sum += _distSquared(points[i], clusterPoints[k][j], ignoredDims);
        }
        meanClusterDist[i] = clusterPoints[k].length > 1
            ? sum / (clusterPoints[k].length - 1).toDouble()
            : sum;
      } else {
        var sum = 0.0;
        for (var j = 0; j < 100; j++) {
          final sample = rng.nextInt(clusterSize);
          sum += _distSquared(points[i], clusterPoints[k][sample], ignoredDims);
        }
        meanClusterDist[i] = sum / 100;
      }
    }

    // Find the 'silhouette' of each point.
    final silhouettes = List<double>.filled(points.length, 0.0);
    for (var i = 0; i < points.length; i++) {
      final c = clusters[i];
      silhouettes[i] = clusterPoints[c].length > 1
          ? (minNeighborDist[i] - meanClusterDist[i]) /
              max(minNeighborDist[i], meanClusterDist[i])
          : 0.0;
    }

    // Return the average silhouette.
    var silhouetteSum = 0.0;
    for (var i = 0; i < points.length; i++) {
      silhouetteSum += silhouettes[i];
    }
    return silhouetteSum / points.length.toDouble();
  })();

  /// Returns the index of the mean that is closest to `point`.
  int nearestMean(List<double> point) {
    var minDist = double.maxFinite;
    var minK = -1;
    for (var j = 0; j < means.length; j++) {
      final dist = _distSquared(point, means[j], ignoredDims);
      if (dist < minDist) {
        minDist = dist;
        minK = j;
      }
    }
    return minK;
  }

  /// Predict the cluster that `point` belongs to by way of a vote among its
  /// `k` nearest neighbors.
  ///
  /// This can be an expensive calculation, as it calculates the distnace to
  /// every point in every cluster in order to find the nearest `k`.
  ///
  /// https://en.wikipedia.org/wiki/K-nearest_neighbors_algorithm
  int kNearestNeighbors(List<double> point, int k) {
    final neighbors = List<MapEntry<double, int>>.generate(
      k,
      (int idx) {
        return const MapEntry<double, int>(double.maxFinite, -1);
      },
    );

    for (var i = 0; i < points.length; i++) {
      final dist = _distSquared(point, points[i], ignoredDims);
      if (dist < neighbors[k - 1].key) {
        neighbors.add(MapEntry<double, int>(dist, clusters[i]));
        neighbors.sort((MapEntry<double, int> a, MapEntry<double, int> b) {
          return a.key.compareTo(b.key);
        });
        neighbors.removeLast();
      }
    }

    // Add 1/d for each point at distance d to the accumulator for its cluster.
    final neighborCounts = List<double>.filled(means.length, 0.0);
    for (var i = 0; i < k; i++) {
      neighborCounts[neighbors[i].value] += 1.0 / neighbors[i].key;
    }

    // Find the cluster with the largest value.
    var maxCount = 0.0;
    var maxIdx = -1;
    for (var i = 0; i < neighborCounts.length; i++) {
      if (neighborCounts[i] > maxCount) {
        maxCount = neighborCounts[i];
        maxIdx = i;
      }
    }

    return maxIdx;
  }

  @override
  String toString() {
    final buf = StringBuffer();
    buf.writeln('K: $k');
    buf.writeln('Means:');
    for (var i = 0; i < means.length; i++) {
      buf.writeln(means[i]);
    }
    buf.writeln();
    buf.writeln('Inertia: $inertia');
    buf.writeln('Silhouette: $silhouette');
    buf.writeln('Exact Silhouette: $exactSilhouette');
    buf.writeln();
    buf.writeln('Points');
    for (var i = 0; i < points.length; i++) {
      buf.writeln('${points[i]} -> ${clusters[i]}');
    }
    return buf.toString();
  }
}

/// The type of the function used by the k-means algorithm to select the
/// initial set of cluster centers.
typedef KMeansInitializer = List<List<double>> Function(
  List<List<double>> points,
  List<int> ignoreDims,
  int k,
  int seed,
);

/// A collection of methods for calculating initial means.
class KMeansInitializers {
  KMeansInitializers._();

  /// Returns an initial set of k means initialized according to the k-means++
  /// algorithm:
  /// https://en.wikipedia.org/wiki/K-means%2B%2B
  static List<List<double>> kMeansPlusPlus(
    List<List<double>> points,
    List<int> ignoredDims,
    int k,
    int seed,
  ) {
    final rng = Random(seed);
    final dim = points[0].length;
    final means = List<List<double>>.generate(k, (int i) {
      return List<double>.filled(dim, 0.0);
    });

    means[0] = points[rng.nextInt(points.length)];
    for (var i = 1; i < k; i++) {
      final ds = points.map((List<double> p) {
        var minDist = double.maxFinite;
        for (var j = 0; j < i; j++) {
          final d = _distSquared(means[j], p, ignoredDims);
          if (d < minDist) {
            minDist = d;
          }
        }
        return minDist;
      }).toList();
      final sum = ds.fold(0.0, (double a, double b) => a + b);
      final ps = ds.map((double x) => x / sum).toList();
      var pointIndex = 0;
      final r = rng.nextDouble();
      var cum = 0.0;
      while (true) {
        cum += ps[pointIndex];
        if (cum > r) {
          break;
        }
        if (pointIndex == ps.length - 1) {
          break;
        }
        pointIndex++;
      }
      means[i] = points[pointIndex];
    }

    return means;
  }

  /// Returns an initial set of `k` cluster centers randomly selected from
  /// `points`.
  static List<List<double>> random(
    List<List<double>> points,
    List<int> ignoredDims,
    int k,
    int seed,
  ) {
    final rng = Random(seed);
    final means = List<List<double>>.generate(
      k,
      (int i) {
        return List<double>.filled(points[0].length, 0.0);
      },
    );
    final selectedIndices = <int>[];
    for (var i = 0; i < k; i++) {
      var next = 0;
      do {
        next = rng.nextInt(points.length);
      } while (selectedIndices.contains(next));
      selectedIndices.add(next);
      means[i] = points[next];
    }
    return means;
  }

  /// Returns a cluster initializer function that simply returns `means`.
  static KMeansInitializer fromArray(List<List<double>> means) {
    return (List<List<double>> points, List<int> ignoreDims, int k, int seed) {
      return means;
    };
  }
}

/// A class for organizing k-means computations with utility methods for
/// finding a good solution.
///
/// https://en.wikipedia.org/wiki/K-means_clustering
///
/// Uses k-means++ (https://en.wikipedia.org/wiki/K-means%2B%2B) for the
/// initial means, and then iterates.
///
/// The points accepted by [KMeans] can have any number of dimensions and are
/// represented by `List<double>`. The distance function is hard-coded to be
/// the euclidan distance.
class KMeans {
  /// [points] gives the list of points to cluster. [ignoreDims] gives a list
  /// of dimensions of [points] to ignore. [labelDim] gives the index of a
  /// label in each point if there is one.
  KMeans(
    this.points, {
    this.ignoredDims = _emptyList,
    this.labelDim = -1,
  }) {
    // Translate points so that the range in each dimension is centered at 0,
    // and scale each point so that the range in each dimension is the same
    // as the largest range of a dimension in [points].
    final dims = points[0].length;
    _scaledPoints = List<List<double>>.generate(points.length, (int i) {
      return List<double>.filled(dims, 0.0);
    });
    // Find the largest range in each dimension.
    final mins = List<double>.filled(dims, double.maxFinite);
    final maxs = List<double>.filled(dims, -double.maxFinite);
    for (var i = 0; i < points.length; i++) {
      for (var j = 0; j < dims; j++) {
        if (points[i][j] < mins[j]) {
          mins[j] = points[i][j];
        }
        if (points[i][j] > maxs[j]) {
          maxs[j] = points[i][j];
        }
      }
    }
    final ranges = List<double>.generate(dims, (int i) {
      return maxs[i] - mins[i];
    });
    var maxRange = -double.maxFinite;
    for (var i = 0; i < dims; i++) {
      if (i == labelDim) {
        continue;
      }
      if (ranges[i] > maxRange) {
        maxRange = ranges[i];
      }
    }
    _translations = List<double>.filled(dims, 0.0);
    _scales = List<double>.filled(dims, 0.0);
    for (var i = 0; i < dims; i++) {
      _translations[i] = mins[i] + ranges[i] / 2.0;
      _scales[i] = i == labelDim ? maxRange * 10.0 : maxRange / ranges[i];
    }
    for (var i = 0; i < points.length; i++) {
      for (var j = 0; j < dims; j++) {
        _scaledPoints[i][j] = (points[i][j] - _translations[j]) * _scales[j];
      }
    }
  }

  /// Numbers closer together than this are considered equivalent.
  static const double defaultPrecision = 1e-4;
  static const List<int> _emptyList = <int>[];

  /// The points to cluster.
  final List<List<double>> points;

  /// Dimensions of [points] that are ignored.
  final List<int> ignoredDims;

  /// The index of the label. Defaults to `-1` if the data is unlabeled.
  final int labelDim;

  // The translation to apply to each dimension.
  late final List<double> _translations;

  // The scaling to apply in each dimension.
  late final List<double> _scales;

  // The points after translating and scaling.
  late final List<List<double>> _scaledPoints;

  /// Returns a [Cluster] of [points] into [k] clusters.
  Clusters fit(
    int k, {
    int maxIterations = 300,
    int seed = 42,
    KMeansInitializer init = KMeansInitializers.kMeansPlusPlus,
    double tolerance = defaultPrecision,
  }) {
    final clusters = List<int>.filled(_scaledPoints.length, 0);
    final means = init(_scaledPoints, ignoredDims, k, seed);

    for (var iters = 0; iters < maxIterations; iters++) {
      // Put points into the closest cluster.
      _populateClusters(means, clusters);

      // Shift means.
      if (!_shiftClusters(clusters, means, tolerance)) {
        break;
      }
      if (iters == maxIterations - 1) {
        print('Reached max iters!');
      }
    }

    final descaledMeans = List<List<double>>.generate(
      means.length,
      (int i) {
        return List<double>.generate(means[0].length, (int j) {
          return means[i][j] / _scales[j] + _translations[j];
        });
      },
    );
    return Clusters(points, ignoredDims, clusters, descaledMeans);
  }

  /// Finds the 'best' k-means [Cluster] over a range of possible values of
  /// 'k'.
  ///
  /// Returns the clustering whose 'k' maximmizes the average 'silhouette'
  /// (https://en.wikipedia.org/wiki/Silhouette_(clustering)).
  Clusters bestFit({
    int maxIterations = 300,
    int seed = 42,
    int minK = 2,
    int maxK = 20,
    int trialsPerK = 1,
    KMeansInitializer init = KMeansInitializers.kMeansPlusPlus,
    double tolerance = defaultPrecision,
    bool useExactSilhouette = false,
  }) {
    Clusters? best;
    var k = minK;
    var trial = 0;

    while (k <= maxK && k <= _scaledPoints.length) {
      final km = fit(
        k,
        maxIterations: maxIterations,
        seed: seed + trial,
        init: init,
        tolerance: tolerance,
      );
      if (useExactSilhouette) {
        if (best == null || km.exactSilhouette > best.exactSilhouette) {
          best = km;
        }
      } else {
        if (best == null || km.silhouette > best.silhouette) {
          best = km;
        }
      }
      trial++;
      if (trial == trialsPerK) {
        k++;
        trial = 0;
      }
    }

    return best!;
  }

  // Put points into the closest cluster.
  void _populateClusters(List<List<double>> means, List<int> outClusters) {
    for (var i = 0; i < _scaledPoints.length; i++) {
      var kidx = 0;
      var kdist = _distSquared(_scaledPoints[i], means[0], ignoredDims);
      for (var j = 1; j < means.length; j++) {
        final dist = _distSquared(_scaledPoints[i], means[j], ignoredDims);
        if (dist < kdist) {
          kidx = j;
          kdist = dist;
        }
      }
      outClusters[i] = kidx;
    }
  }

  // Shift cluster means.
  bool _shiftClusters(
    List<int> clusters,
    List<List<double>> means,
    double tolerance,
  ) {
    var shifted = false;
    final dim = means[0].length;
    for (var i = 0; i < means.length; i++) {
      final newMean = List<double>.filled(dim, 0.0);
      var n = 0.0;
      for (var j = 0; j < _scaledPoints.length; j++) {
        if (clusters[j] != i) {
          continue;
        }
        for (var m = 0; m < dim; m++) {
          if (ignoredDims.contains(m)) {
            continue;
          }
          newMean[m] = (newMean[m] * n + _scaledPoints[j][m]) / (n + 1.0);
        }
        n += 1.0;
      }
      for (var m = 0; m < dim; m++) {
        if (ignoredDims.contains(m)) {
          continue;
        }
        if ((means[i][m] - newMean[m]).abs() > tolerance) {
          shifted = true;
          break;
        }
      }
      means[i] = newMean;
    }
    return shifted;
  }
}

double _distSquared(List<double> a, List<double> b, List<int> ignoredDims) {
  assert(a.length == b.length);

  final length = a.length;
  var sum = 0.0;
  for (var i = 0; i < length; i++) {
    if (ignoredDims.contains(i)) {
      continue;
    }
    final diff = a[i] - b[i];
    final diffSquared = diff * diff;
    sum += diffSquared;
  }

  return sum;
}
