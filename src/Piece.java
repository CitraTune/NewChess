import javax.swing.*;
import java.awt.*;
import java.util.ArrayList;
import java.util.List;

public class Piece {


    static ImageIcon imgSmoother(ImageIcon largeimg){

        Image image = largeimg.getImage(); // transform it
        Image newimg = image.getScaledInstance(Board.intSqScale, Board.intSqScale,  java.awt.Image.SCALE_SMOOTH); // scale it the smooth way
        largeimg = new ImageIcon(newimg);
        return(largeimg);
    }
    int xCor;
    int yCor;
    boolean color;
    boolean movedYet;
    boolean moveAttack;
    boolean moveOnly;
    boolean attackOnly;
    String name;
    JLabel labelIcon = new JLabel();
    private List<IntPair> moveAtkAbs = new ArrayList<>();
    private List<IntPair> moveOnlyAbs = new ArrayList<>();
    private List<IntPair> atkOnlyAbs = new ArrayList<>();
    private List<IntPair> movementRel = new ArrayList<>();
    private List<IntPair> attackRel = new ArrayList<>();
    private List<IntPair> attackRelRange = new ArrayList<>();
    private final List<JLabel> tranSquares = new ArrayList<>();
    private JLabel tranSquare;
    public static boolean castled = false;


    public void paintEnableCoord(int x, int y){
        tranSquare = new JLabel(imgSmoother(Board.imgRed));
        if (!Board.turn) {
            tranSquare.setBounds(Board.intSqScale + x * Board.intSqScale, Board.intSqScale - ((y - 7) * Board.intSqScale), Board.intSqScale, Board.intSqScale);
        }
        else {
            tranSquare.setBounds(Board.intSqScale + x * Board.intSqScale, Board.intSqScale + y * Board.intSqScale, Board.intSqScale, Board.intSqScale);
        }
        Board.mainPane.add(tranSquare, JLayeredPane.PALETTE_LAYER);

    }
    public void scrapeCoord(){
        Board.mainPane.remove(tranSquare);

    }
    public void paintRelCoords() {
        for (int i = 0; i < getMovementRel().size(); i++ ){
            IntPair relPair = getMovementRel().get(i);
            int relX = relPair.getX();
            int relY = relPair.getY();
            tranSquares.add(new JLabel(imgSmoother(Board.imgRed)));
            if (!Board.turn) {
                tranSquares.get(i).setBounds(Board.intSqScale + relX * Board.intSqScale, Board.intSqScale - ((relY - 7) * Board.intSqScale), Board.intSqScale, Board.intSqScale);
            }
            else {
                tranSquares.get(i).setBounds(Board.intSqScale + relX * Board.intSqScale, Board.intSqScale + relY * Board.intSqScale, Board.intSqScale, Board.intSqScale);
            }
            Board.mainPane.add(tranSquares.get(i), JLayeredPane.PALETTE_LAYER);
        }

    }

    public void scrapeRelCoords() {
        for (int i = 0; i < getMovementRel().size(); i++ ){
            IntPair relPair = getMovementRel().get(i);
            int relX = relPair.getX();
            int relY = relPair.getY();
            Board.mainPane.remove(tranSquares.get(i));
            Board.mainPane.revalidate();    // Revalidate the panel
            Board.mainPane.repaint();       // Repaint the panel
        }
    }
    public void movedOnce(){
        if (!movedYet) {
            if (this instanceof Pawn) {
                getMoveOnlyAbs().remove(1);
            }
            movedYet = true;
        }
    }
    //True = white, false = black
    public void pieceMove (int xCorNew, int yCorNew){
        //Changes filledList2d the array and make xCorOld and yCorOld be false, then make the xCorNew and yCorNew be true.
        //Changes the object on that square.
        setxCor(xCorNew);
        setyCor(yCorNew);
        Board.pieceMap.forcePut(new Pair<>(xCorNew, yCorNew), this);
        if (!Board.turn) {
            labelIcon.setBounds(Board.intSqScale + xCor * Board.intSqScale, Board.intSqScale - ((yCor - 7) * Board.intSqScale), Board.intSqScale, Board.intSqScale);
        }
        else{
            labelIcon.setBounds(Board.intSqScale + xCor * Board.intSqScale, Board.intSqScale +yCor * Board.intSqScale, Board.intSqScale, Board.intSqScale);
        }
        Board.mainPane.revalidate();    // Revalidate the panel
        Board.mainPane.repaint();       // Repaint the panel
        Board.movesLeft--;
        movedOnce();
        if (Board.movesLeft==0){
            EndTurn.glow();
        }
    }
    public void kill (){
        Board.mainPane.remove(labelIcon); // Remove label2
        Board.mainPane.revalidate();    // Revalidate the panel
        Board.mainPane.repaint();       // Repaint the panel

    }

    public int getxCor() {
        return xCor;
    }

    public void setxCor(int xCor) {
        this.xCor = xCor;
    }

    public int getyCor() {
        return yCor;
    }

    public void setyCor(int yCor) {
        this.yCor = yCor;
    }
    public Piece(int xCor, int yCor, boolean color, String name) {
        this.xCor = xCor;
        this.yCor = yCor;
        this.color = color;
        this.name = name;
        Board.pieceMap.put(new Pair<>(xCor, yCor), this);
    }

    public List<IntPair> getMoveAtkAbs() {
        return moveAtkAbs;
    }
    public List<IntPair> getMoveOnlyAbs() {
        return moveOnlyAbs;
    }public List<IntPair> getAtkOnlyAbs() {
        return atkOnlyAbs;
    }


    public void setMovementAbs(List<IntPair> movementAbs) {
        this.moveAtkAbs = movementAbs;
    }

    public List<IntPair> getMovementRel() {
        return movementRel;
    }

    public void setMovementRel(List<IntPair> movementRel) {
        this.movementRel = movementRel;
    }


    public List<IntPair> getAttackRel() {
        return attackRel;
    }

    public List<IntPair> getAttackRelRange() {
        return attackRelRange;
    }

    public void setAttackRelRange(List<IntPair> attackRelRange) {
        this.attackRelRange = attackRelRange;
    }
}
