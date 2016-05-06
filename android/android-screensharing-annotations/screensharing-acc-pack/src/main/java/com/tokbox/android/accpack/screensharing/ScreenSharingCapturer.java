package com.tokbox.android.accpack.screensharing;

import android.annotation.TargetApi;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Point;
import android.media.Image;
import android.media.ImageReader;
import android.os.Build;
import android.os.Handler;
import android.util.Log;
import android.view.View;

import com.opentok.android.BaseVideoCapturer;

import java.io.FileOutputStream;
import java.nio.ByteBuffer;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

public class ScreenSharingCapturer extends BaseVideoCapturer{
    private static final String LOG_TAG = ScreenSharingFragment.class.getSimpleName();
    private Context mContext;

    private boolean capturing = false;
    private View contentView;

    private int fps = 15;
    private int width = 0;
    private int height = 0;
    private int[] frame;

    private Bitmap bmp;
    private Canvas canvas;

    private Handler mHandler = new Handler();

    private ImageReader mImageReader;

    Bitmap lastBmp;

    private final Lock mImageReaderLock = new ReentrantLock(true /*fair*/);

    private Runnable newFrame = new Runnable() {
        @TargetApi(Build.VERSION_CODES.KITKAT)
        @Override
        public void run() {
            if (capturing) {
                frame = null;
                int width = contentView.getWidth();
                int height = contentView.getHeight();

                if (frame == null ||
                        ScreenSharingCapturer.this.width != width ||
                        ScreenSharingCapturer.this.height != height) {

                    ScreenSharingCapturer.this.width = width;
                    ScreenSharingCapturer.this.height = height;

                    if (lastBmp != null){
                        canvas = new Canvas(lastBmp);
                        frame = new int[width * height];

                        canvas.save(Canvas.MATRIX_SAVE_FLAG);
                        canvas.translate(-contentView.getScrollX(), -contentView.getScrollY());
                        contentView.draw(canvas);

                        lastBmp.getPixels(frame, 0, width, 0, 0, width, height);

                        provideIntArrayFrame(frame, ARGB, width, height, 0, false);

                        canvas.restore();

                        if (lastBmp != null) {
                            lastBmp.recycle();
                            lastBmp = null;
                        }
                    }

                    mHandler.postDelayed(newFrame, 1000 / fps);


                }
            }
        }
    };


    @TargetApi(Build.VERSION_CODES.KITKAT)
    public ScreenSharingCapturer(Context context, View view, ImageReader imageReader, Point size) {
        this.mContext = context;
        this.contentView = view;
        this.mImageReader = imageReader;
        this.mImageReader.setOnImageAvailableListener(new ImageAvailableListener(), null);

        this.width = size.x;
        this.height = size.y;
    }

    @Override
    public void init() {

    }

    @Override
    public int startCapture() {
        capturing = true;

        mHandler.postDelayed(newFrame, 1000 / fps);
        return 0;
    }

    @Override
    public int stopCapture() {
        capturing = false;
        mHandler.removeCallbacks(newFrame);
        return 0;
    }

    @Override
    public boolean isCaptureStarted() {
        return capturing;
    }

    @Override
    public CaptureSettings getCaptureSettings() {

        CaptureSettings settings = new CaptureSettings();
        settings.fps = fps;
        settings.width = width;
        settings.height = height;
        settings.format = ARGB;
        return settings;
    }

    @Override
    public void destroy() {

    }

    @Override
    public void onPause() {

    }

    @Override
    public void onResume() {

    }


    @TargetApi(Build.VERSION_CODES.KITKAT)
    private class ImageAvailableListener implements ImageReader.OnImageAvailableListener {

        @Override
        public void onImageAvailable(ImageReader reader) {
            Log.i(LOG_TAG, " onImageAvailable");

                Image mImage = null;
                FileOutputStream fos = null;

                try {
                    mImage = mImageReader.acquireLatestImage();
                    Log.i(LOG_TAG, " NEW IMAGE");

                    if (mImage != null) {
                        Image.Plane[] planes = mImage.getPlanes();
                        ByteBuffer buffer = planes[0].getBuffer();
                        int pixelStride = planes[0].getPixelStride();
                        int rowStride = planes[0].getRowStride();
                        int rowPadding = rowStride - pixelStride * width;

                        // create bitmap
                        bmp = Bitmap.createBitmap(width + rowPadding / pixelStride, height, Bitmap.Config.ARGB_8888);
                        bmp.copyPixelsFromBuffer(buffer);
                        lastBmp = Bitmap.createBitmap(bmp);

                    }

                } catch (Exception e) {
                    e.printStackTrace();
                } finally {
                    if (bmp != null) {
                        bmp.recycle();
                    }

                    if (mImage != null) {
                        mImage.close();
                    }
                }

        }
    }
}