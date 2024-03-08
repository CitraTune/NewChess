import javax.imageio.ImageIO;
import javax.swing.*;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

public class Bishop extends Piece{

    static ImageIcon imgBishopW;
    static {
        try {
            imgBishopW = new ImageIcon(ImageIO.read(images.gfras("resources/Tabler-icons_chess-bishop.svg.png")));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
    static ImageIcon imgBishopB;
    static {
        try {
            imgBishopB = new ImageIcon(ImageIO.read(images.gfras("resources/Tabler-icons_chess-bishop-filled.svg.png")));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }



    public Bishop(int xCor, int yCor, boolean color, String name) {
        super(xCor, yCor, color, name);
        //List<IntPair> movementAbs = new ArrayList<>();
        // Bishop can move diagonally
        for (int i = -7; i <= 7; i++) {
            if (i != 0) {
                getMoveAtkAbs().add(new IntPair(i, i));
                getMoveAtkAbs().add(new IntPair(i, -i));
            }
        }
        moveAttack = true;
        if (color) {
            setLabelIcon(new JLabel(imgSmoother(imgBishopW)));
        } else {
            setLabelIcon(new JLabel(imgSmoother(imgBishopB)));
        }
        getLabelIcon().setBounds(40 +xCor*40, 40 +yCor*40, 40, 40);
        Board.mainPane.add(getLabelIcon(), JLayeredPane.PALETTE_LAYER);
    }

}