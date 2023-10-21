import javax.imageio.ImageIO;
import javax.swing.*;
import java.io.IOException;

public class Queen extends Piece{
    static ImageIcon imgQueenW;
    static {
        try {
            imgQueenW = new ImageIcon(ImageIO.read(images.gfras("resources/Tabler-icons_chess-queen.svg.png")));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
    static ImageIcon imgQueenB;
    static {
        try {
            imgQueenB = new ImageIcon(ImageIO.read(images.gfras("resources/Tabler-icons_chess-queen-filled.svg.png")));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }


    public Queen(int xCor, int yCor, boolean color, String name) {
        super(xCor, yCor, color, name);

        // Queen can move diagonally, horizontally, and vertically
        for (int i = -7; i <= 7; i++) {
            if (i != 0) {
                getMovementAbs().add(new IntPair(i, i));
                getMovementAbs().add(new IntPair(i, -i));
                getMovementAbs().add(new IntPair(i, 0));
                getMovementAbs().add(new IntPair(0, i));
            }
        }
        for (int i = -7; i <= 7; i++) {
            if (i != 0) {

                if((i+xCor) <= 7 && (i + xCor) >= 0 && (i + yCor) >= 0 && (i + yCor) <= 7) {
                    getMovementRel().add(new IntPair(i + xCor, i + yCor));
                }
                if((i+xCor) <= 7 && (i + xCor) >= 0 && (-i + yCor) >= 0 && (-i + yCor) <= 7) {
                    getMovementRel().add(new IntPair(i + xCor, -i + yCor));
                }
                if((i+xCor) <= 7 && (i + xCor) >= 0) {
                    getMovementRel().add(new IntPair(i + xCor, yCor));
                }
                if((i+yCor) <= 7 && (i + yCor) >= 0) {
                    getMovementRel().add(new IntPair(xCor, i + yCor));
                }
            }
        }

        if (color) {
            labelIcon = new JLabel(imgSmoother(imgQueenW));
        } else {
            labelIcon = new JLabel(imgSmoother(imgQueenB));
        }
        labelIcon.setBounds(40 +xCor*40, 40 +yCor*40, 40, 40);
        Board.mainPane.add(labelIcon, JLayeredPane.PALETTE_LAYER);
    }

}