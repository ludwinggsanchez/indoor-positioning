// Adapted from here:
// https://web.archive.org/web/20140131183356/http://interactive-matter.eu/blog/2009/12/18/filtering-sensor-data-with-a-kalman-filter/
// https://github.com/bachagas/Kalman/blob/master/Kalman.h


class KalmanFilter {
    KalmanFilter({this.q, this.r, this.x, this.p, this.k});
    
    /* Kalman filter variables */
    double q; //process noise covariance
    double r; //measurement noise covariance
    double x; //value
    double p; //estimation error covariance
    double k; //kalman gain

    double getFilteredValue(double measurement) {
      p = p + q;

      // measurement update
      k = p / (p + r);
      x = x + k * (measurement - x);
      p = (1 - k) * p;

      return x;
    }

    void setParameters(double processNoise, double sensorNoise, double estimatedError) {
        q = processNoise;
        r = sensorNoise;
        p = estimatedError;
    }

/*
    void setParameters(double process_noise, double sensor_noise) {
        q = process_noise;
        r = sensor_noise;
    }
 */   
    double getProcessNoise() {
      return q;
    }
    
    double getSensorNoise() {
      return r;
    }
    
    double getEstimatedError() {
      return p;
    }
}