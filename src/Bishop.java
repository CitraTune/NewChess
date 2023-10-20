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
                getMovementAbs().add(new IntPair(i, i));
                getMovementAbs().add(new IntPair(i, -i));
            }
        }
//        for (int i = -7; i <= 7; i++) {
//            if (i != 0) {
//                //Represents the current coordinates the function is evaluating to see if it should highlight
//                int xCorCur = i + xCor;
//                int yCorCur = i + yCor;
//                Piece clickPiece = Board.pieceMap.get(new Pair<>(xCorCur,yCorCur));
//                //Need the xs to not go above 7 or below 0, and checks if there is a piece there.
//                if(xCorCur <= 7 && xCorCur >= 0 && yCorCur >= 0 && yCorCur <= 7 && (clickPiece.color != this.color || clickPiece == null)) {
//                    movementRel.add(new IntPair(xCorCur, yCorCur));
//                }
//                int yCorCurN = -i + yCor;
//                if(xCorCur <= 7 && xCorCur >= 0 && yCorCurN >= 0 && yCorCurN <= 7) {
//                    movementRel.add(new IntPair(xCorCur, yCorCurN));
//                }
//
//
//            }
//        }
        JLabel labelIcon = new JLabel();
        if (color) {
            labelIcon = new JLabel(imgSmoother(imgBishopW));
        } else if (!color) {
            labelIcon = new JLabel(imgSmoother(imgBishopB));
        }
        labelIcon.setBounds(40 +xCor*40, 40 +yCor*40, 40, 40);
        Board.filledList2D[xCor][yCor] = true;
        JLayeredPane lp = Board.mainPane;
        lp.add(labelIcon, JLayeredPane.PALETTE_LAYER);
    }

}