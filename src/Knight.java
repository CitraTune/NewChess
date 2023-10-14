import javax.swing.*;

public class Knight extends Piece{
    static ImageIcon imgKnightW = new ImageIcon("C:\\Users\\awesome22\\Downloads\\Tabler-icons_chess-knight.svg.png");
    static ImageIcon imgKnightB = new ImageIcon("C:\\Users\\awesome22\\Downloads\\Tabler-icons_chess-knight-filled.svg.png");


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

        JLabel labelIcon = new JLabel();
        if (color) {
            labelIcon = new JLabel(imgSmoother(imgKnightW));
        } else if (!color) {
            labelIcon = new JLabel(imgSmoother(imgKnightB));
        }
        labelIcon.setBounds(40 +xCor*40, 40 +yCor*40, 40, 40);
        Board.filledList2D[xCor][yCor] = true;
        JLayeredPane lp = Board.mainPane;
        lp.add(labelIcon, JLayeredPane.PALETTE_LAYER);
    }


}