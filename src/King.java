import javax.swing.*;
import java.util.ArrayList;
import java.util.List;

public class King extends Piece{
    static ImageIcon imgKingW = new ImageIcon("C:\\Users\\awesome22\\Downloads\\Tabler-icons_chess-king.svg.png");
    static ImageIcon imgKingB = new ImageIcon("C:\\Users\\awesome22\\Downloads\\Tabler-icons_chess-king-filled.svg.png");

    public King(int xCor, int yCor, boolean color, String name) {
        super(xCor, yCor, color, name);
        List<IntPair> kingMovement = new ArrayList<>();
        // King can move one step in any direction
        for (int i = -1; i <= 1; i++) {
            for (int j = -1; j <= 1; j++) {
                if (i != 0 || j != 0) {
                    kingMovement.add(new IntPair(i, j));
                }
            }
        }
        JLabel labelIcon = new JLabel();
        if (color) {
            labelIcon = new JLabel(imgSmoother(imgKingW));
        } else if (!color) {
            labelIcon = new JLabel(imgSmoother(imgKingB));
        }
        labelIcon.setBounds(40 +xCor*40, 40 +yCor*40, 40, 40);
        Board.filledList2D[xCor][yCor] = true;
        JLayeredPane lp = Board.mainPane;
        lp.add(labelIcon, JLayeredPane.PALETTE_LAYER);
    }

}