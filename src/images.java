import javax.swing.*;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.InputStream;

public class images {
    //Honestly the code below is copied. It just makes a transparent square. Too much effort for something so simple and low use
    public static void makeIconTransparent(ImageIcon icon) {
        // Get the image from the ImageIcon
        Image image = icon.getImage();
        // Create a BufferedImage for customizing transparency
        BufferedImage bufferedImage = new BufferedImage(
                icon.getIconWidth(), icon.getIconHeight(), BufferedImage.TYPE_INT_ARGB);
        // Create a Graphics2D object to work with the BufferedImage
        Graphics2D g2d = bufferedImage.createGraphics();
        // Set the transparency using AlphaComposite
        g2d.setComposite(AlphaComposite.getInstance(AlphaComposite.SRC_OVER, (float) 0.5));
        // Draw the original image onto the BufferedImage
        g2d.drawImage(image, 0, 0, null);
        // Dispose of the Graphics2D object
        g2d.dispose();
        // Update the ImageIcon with the modified image
        icon.setImage(bufferedImage);
    }
    //gfras stands for getFileFromResourceAsStream
    public static InputStream gfras(String fileName) {

        ClassLoader classLoader = Board.class.getClassLoader();
        InputStream inputStream = classLoader.getResourceAsStream(fileName);

        if (inputStream == null) {
            throw new IllegalArgumentException("file not found! " + fileName);
        } else {
            return inputStream;
        }

    }
}

