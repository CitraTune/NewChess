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
        getMoveAtkAbs().add(new IntPair(2, 1));
        getMoveAtkAbs().add(new IntPair(1, 2));
        getMoveAtkAbs().add(new IntPair(-1, 2));
        getMoveAtkAbs().add(new IntPair(-2, 1));
        getMoveAtkAbs().add(new IntPair(-2, -1));
        getMoveAtkAbs().add(new IntPair(-1, -2));
        getMoveAtkAbs().add(new IntPair(1, -2));
        getMoveAtkAbs().add(new IntPair(2, -1));
        moveAttack = true;
        if (color) {
            setLabelIcon(new JLabel(imgSmoother(imgKnightW)));
        } else {
            setLabelIcon(new JLabel(imgSmoother(imgKnightB)));
        }

        getLabelIcon().setBounds(40 +xCor*40, 40 +yCor*40, 40, 40);
        Board.mainPane.add(getLabelIcon(), JLayeredPane.PALETTE_LAYER);
    }


}