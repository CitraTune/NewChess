import javax.imageio.ImageIO;
import javax.swing.*;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

public class King extends Piece{
    static ImageIcon imgKingW;
    static {
        try {
            imgKingW = new ImageIcon(ImageIO.read(images.gfras("resources/Tabler-icons_chess-king.svg.png")));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
    static ImageIcon imgKingB;
    static {
        try {
            imgKingB = new ImageIcon(ImageIO.read(images.gfras("resources/Tabler-icons_chess-king-filled.svg.png")));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
    public void kingCastleCheck(){
        if (!movedYet) {
            if (!Board.pieceMap.get(new Pair<>(7, 7)).movedYet && Board.pieceMap.get(new Pair<>(6,7)) == null && Board.pieceMap.get(new Pair<>(5,7))==null) {
                paintEnableCoord(7,7);
            }
            if (!Board.pieceMap.get(new Pair<>(7, 7)).movedYet&& Board.pieceMap.get(new Pair<>(3,7)) == null && Board.pieceMap.get(new Pair<>(2,7))==null&& Board.pieceMap.get(new Pair<>(1,7))==null) {
                paintEnableCoord(7,7);
            }
        }
    }


    public King(int xCor, int yCor, boolean color, String name) {
        super(xCor, yCor, color, name);
        // King can move one step in any direction
        for (int i = -1; i <= 1; i++) {
            for (int j = -1; j <= 1; j++) {
                if (i != 0 || j != 0) {
                    getMoveAtkAbs().add(new IntPair(i, j));
                }
            }
        }
        moveAttack = true;
        if (color) {
            labelIcon = new JLabel(imgSmoother(imgKingW));
        } else {
            labelIcon = new JLabel(imgSmoother(imgKingB));
        }
        labelIcon.setBounds(40 +xCor*40, 40 +yCor*40, 40, 40);
        Board.mainPane.add(labelIcon, JLayeredPane.PALETTE_LAYER);
    }

}