import javax.imageio.ImageIO;
import javax.swing.*;
import java.io.IOException;

public class Rook extends Piece{

    static ImageIcon imgRookW;
    static {
        try {
            imgRookW = new ImageIcon(ImageIO.read(images.gfras("resources/Tabler-icons_chess-rook.svg.png")));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
    static ImageIcon imgRookB;
    static {
        try {
            imgRookB = new ImageIcon(ImageIO.read(images.gfras("resources/Tabler-icons_chess-rook-filled.svg.png")));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }


    //Objectname.PaintRelCoords()



    public void newPosition(){
        getMovementRel().clear();
    }




    public Rook(int xCor, int yCor, boolean color, String name) {
        super(xCor, yCor, color, name);

        // Rook can move horizontally and vertically
        for (int i = -7; i <= 7; i++) {
            if (i != 0) {
                getMoveAtkAbs().add(new IntPair(i, 0));
                getMoveAtkAbs().add(new IntPair(0, i));

            }
        }

        for (int i = -7; i <= 7; i++) {
            if (i != 0) {
                if((i+xCor) <= 7 && (i + xCor) >= 0) {
                    getMovementRel().add(new IntPair(i + xCor, yCor));
                }
                if((i+yCor) <= 7 && (i + yCor) >= 0) {
                    getMovementRel().add(new IntPair(xCor, i + yCor));
                }

            }
        }
        //How to access the object itself when running the declaration. I need the map to know the xCor and yCor of the object.
        moveAttack = true;
        if (color) {
            labelIcon = new JLabel(imgSmoother(imgRookW));
        } else {
            labelIcon = new JLabel(imgSmoother(imgRookB));
        }
        labelIcon.setBounds(40 +xCor*40, 40 +yCor*40, 40, 40);
        Board.mainPane.add(labelIcon, JLayeredPane.PALETTE_LAYER);
    }

}