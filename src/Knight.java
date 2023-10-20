import javax.imageio.ImageIO;
import javax.swing.*;
import java.io.IOException;

public class Knight extends Piece{
    static ImageIcon imgKnightW;
    static {
        try {
            imgKnightW = new ImageIcon(ImageIO.read(images.gfras("resources/Tabler-icons_chess-knight.svg.png")));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
    static ImageIcon imgKnightB;
    static {
        try {
            imgKnightB = new ImageIcon(ImageIO.read(images.gfras("resources/Tabler-icons_chess-knight-filled.svg.png")));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }


    public Knight(int xCor, int yCor, boolean color, String name){
        super(xCor, yCor, color, name);

        // Knight can move in an L-shape pattern
        getMovementAbs().add(new IntPair(2, 1));
        getMovementAbs().add(new IntPair(1, 2));
        getMovementAbs().add(new IntPair(-1, 2));
        getMovementAbs().add(new IntPair(-2, 1));
        getMovementAbs().add(new IntPair(-2, -1));
        getMovementAbs().add(new IntPair(-1, -2));
        getMovementAbs().add(new IntPair(1, -2));
        getMovementAbs().add(new IntPair(2, -1));

        getMovementRel().add(new IntPair(2, 1));
        getMovementRel().add(new IntPair(1, 2));
        getMovementRel().add(new IntPair(-1, 2));
        getMovementRel().add(new IntPair(-2, 1));
        getMovementRel().add(new IntPair(-2, -1));
        getMovementRel().add(new IntPair(-1, -2));
        getMovementRel().add(new IntPair(1, -2));
        getMovementRel().add(new IntPair(2, -1));

        JLabel labelIcon;
        if (color) {
            labelIcon = new JLabel(imgSmoother(imgKnightW));
        } else {
            labelIcon = new JLabel(imgSmoother(imgKnightB));
        }
        labelIcon.setBounds(40 +xCor*40, 40 +yCor*40, 40, 40);
        Board.filledList2D[xCor][yCor] = true;
        JLayeredPane lp = Board.mainPane;
        lp.add(labelIcon, JLayeredPane.PALETTE_LAYER);
    }


}