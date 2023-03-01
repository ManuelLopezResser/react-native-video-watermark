package me.vyoo;

import android.graphics.Bitmap;
import android.graphics.Matrix;

public class Utils {    

    public static Bitmap scaleBitmap(Bitmap bitmap, Float scale) {
        int w = bitmap.getWidth();
        int h = bitmap.getHeight();

        Matrix mtx = new Matrix();
        if (scale != 1 && scale >= 0) {
            mtx.postScale(scale, scale);
        }

        Bitmap scaledBitmap = null;

        try {
            scaledBitmap = Bitmap.createBitmap(bitmap, 0, 0, w, h, mtx, true);
        } catch (OutOfMemoryError e) {
            System.out.print(e.getMessage());
            while(scaledBitmap == null) {
                System.gc();
                System.runFinalization();
                scaledBitmap = Bitmap.createBitmap(bitmap, 0, 0, w, h, mtx, true);
            }
        }
        return scaledBitmap;
    }  
   


}
