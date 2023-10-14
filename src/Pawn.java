import javax.swing.*;

class Pawn extends Piece{
    static ImageIcon imgPawnW = new ImageIcon("C:\\Users\\awesome22\\Downloads\\Tabler-icons_chess.svg.png");
    static ImageIcon imgPawnB = new ImageIcon("C:\\Users\\awesome22\\Downloads\\Tabler-icons_chess-filled.svg.png");



    public Pawn(int xCor, int yCor, boolean color, String name) {
        super(xCor, yCor, color, name);

        //Need method that puts the object name first, syntax says pawnW1.getMovement and this is equivalent to the ArrayList of the movement possibilities (Absolute)
        getMovementAbs().add(new IntPair(0, 1));
        getMovementAbs().add(new IntPair(0,2));

        //Add system that removes the part from movementAbs when the movement that moves 2 up is selected
        getMovementRel().add(new IntPair(0, 1));
        getMovementRel().add(new IntPair(0,2));


        //Make these checks run everytime the button it is on is clicked.
//        if (color){
//        if (Board.filledList2D[xCor +1][yCor +1]){
//            movement.add(new IntPair(0, 1));
//
//        }
//        else if (!Board.filledList2D[xCor-1][yCor+1]){
//            movement.add(new IntPair(0, 1));
//
//        }}
//        else if (!color){
//            if (Board.filledList2D[xCor+1][xCor -1]){
//                movement.add(new IntPair(0, 1));
//
//            }
//            else if (!Board.filledList2D[xCor-1][yCor -1]){
//                movement.add(new IntPair(0, 1));
//
//            }
//        }

        JLabel labelIcon = new JLabel();
        if (color) {
            labelIcon = new JLabel(imgSmoother(imgPawnW));
        } else if (!color) {
            labelIcon = new JLabel(imgSmoother(imgPawnB));
        }
        labelIcon.setBounds(40 +xCor*40, 40 +yCor*40, 40, 40);
        Board.filledList2D[xCor][yCor] = true;
        JLayeredPane lp = Board.mainPane;
        lp.add(labelIcon, JLayeredPane.PALETTE_LAYER);
    }

}