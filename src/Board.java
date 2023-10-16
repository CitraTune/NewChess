import javax.swing.*;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.util.*;

public class Board {
    int intSqScale = 40;

    JButton[][] btnList2d = new JButton[8][8];
    static boolean[][] filledList2D = new boolean[8][8];

    public static Map<Pair<Integer, Integer>, Piece> pieceMap = new HashMap<>();
    private static boolean isBetween(int a, int b, int c) {
        return a < b && b < c || c < b && b < a;
    }
    JFrame f = new JFrame();
    public static boolean moveAttempt = false;
    static ImageIcon imgBrown = new ImageIcon("C:\\Users\\awesome22\\Downloads\\brownsquare.png");
    static ImageIcon imgBeige = new ImageIcon("C:\\Users\\awesome22\\Downloads\\beigesquare.png");
    static ImageIcon imgRed = new ImageIcon("C:\\Users\\awesome22\\Downloads\\transquarantRed.png");
    public static JLayeredPane mainPane = new JLayeredPane();
    //Honestly the code below is copied. It just makes a transparent square. Too much effort for something so simple
    private void makeIconTransparent(ImageIcon icon) {
        // Get the image from the ImageIcon
        Image image = icon.getImage();
        // Create a BufferedImage for customizing transparency
        BufferedImage bufferedImage = new BufferedImage(
                icon.getIconWidth(), icon.getIconHeight(), BufferedImage.TYPE_INT_ARGB);
        // Create a Graphics2D object to work with the BufferedImage
        Graphics2D g2d = bufferedImage.createGraphics();
        // Set the transparency using AlphaComposite
        g2d.setComposite(AlphaComposite.getInstance(AlphaComposite.SRC_OVER, (float) 0.5));
        // Draw the original image onto the BufferedImage
        g2d.drawImage(image, 0, 0, null);
        // Dispose of the Graphics2D object
        g2d.dispose();
        // Update the ImageIcon with the modified image
        icon.setImage(bufferedImage);
    }

    //NEXT BIG STEP: MAKE A SYSTEM TO READ ANY SPOT ON THE BOARD AND IDENTIFY WHICH PIECE IS THERE
    //Do Hashmap.get(x).get(y); This should be a Piece Object, return it.
    static void buttonClick(int x, int y) {
        //moveAttempt = true;
        //Pair clickpair = new Pair<>(x,y);


        Piece clickPiece = pieceMap.get(new Pair<>(x,y));
        //Following code is when a button is clicked and if there is a piece on it. clickPiece references that piece.
        if (clickPiece != null) {
            String clickPcName = clickPiece.name;
            System.out.println(clickPcName);
            //Create system that takes movementAbs of this clickPiece and goes through every single movement possibility and adds the x and y.
            //Needs checks to see if moving there is possible. Hard to do, have to understand line of sight.
            //Optimal choice: If the coord is "further" than a failed one which is logged somehow, then do not include.

            //These are variables that represent past coordinates of squares that do have pieces. Used to check line of sight.
            ArrayList<Integer> relCheckX = new ArrayList<>();
            ArrayList<Integer> relCheckY = new ArrayList<>();
            System.out.println(x+", "+y);

            //Cycles through every clickPiece movement value
            for (int i = 0; i < clickPiece.getMovementAbs().size(); i++) {

                //Adds the spots relative to the current location to
                //clickPiece is where was clicked. getMovementAbs gets an array of where that piece goes. get(i) shuffles through every piece in the array. getX/Y get the individual coord points.
                //Adding x onto the end adds the current coordinate spot to the movement system which is relative to the piece. this makes it relative to the board instead of the piece.
                int xView = clickPiece.getMovementAbs().get(i).getX() + x;
                int yView = clickPiece.getMovementAbs().get(i).getY() + y;
                int xViewRel = xView-x;
                int yViewRel = yView-y;
                Piece viewedPiece = pieceMap.get(new Pair<>(xView, yView));
                IntPair relAdd = new IntPair(xView,yView);
                boolean addCheck = true;

                //Checks if the tile is on the board
                if(xView <= 7 && xView >= 0 && yView >= 0 && yView <= 7) {
                    //Checks if the viewedPiece's coords (the one that is on the current cycle in the array's coord list made absolute) has a piece there (if viwedPiece exists)
                    if (viewedPiece != null) {
                        //Runs if the coordinate xView,yView is occupied
                        relCheckX.add(xViewRel);
                        relCheckY.add(yViewRel);
                        //Checks if the piece is the same color as it. Does not add the piece to the target spaces if it is.
                        if (clickPiece.color == viewedPiece.color){
                            addCheck = false;
                            System.out.println("overlap");
                        }
                    }
                    //Check for line of sight blockage
                    else {
                        //REPLACE THE 3 WITH THE RELCHECKX and THE 6 WITH RELCHECKY. Also make the for loop work. And make this take priority over the viewedPiece != null.
                        //for (int j = 0; j < relCheckX.size(); j++) {


                        if (x == xView && 3 == x && ((6 > y && 6 < yView) || (6 < y && 6 > yView))) {
                            addCheck= false; // Obstacle is in the queen's vertical path
                            //break;
                        }
                        if (y == yView && 6 == y && ((3 > x && 3 < xView) || (3 < x && 3 > xView))) {
                            addCheck= false; // Obstacle is in the queen's horizontal path
                            //break;
                        }
                        if (Math.abs(x - xView) == Math.abs(y - yView) && Math.abs(x - 3) == Math.abs(y - 6) && Math.abs(xView - 3) == Math.abs(yView - 6)) {
                            addCheck= false; // Obstacle is in the queen's diagonal path
                            //break;
                        }
                        //}
                    }



                }
                else{
                    addCheck = false;
                }
                //Following the principal that pieces move in one general direction, if xRelAdd is negative and relCheckX is negative, compare them(notsurehow). Repeat for y. Log both.
                //If either x or y are greater than or equal to their logged "relCheck" counterparts, don't add it to the movementRel.
                //Make exception rule for this to exclude pieces that move uniquely(include knights base). for knights, just check if the square is occupied and if it's an enemy. then ur good to go.
                if (addCheck) {
                    //if addCheck is true, then this means add the square
                    clickPiece.getMovementRel().clear();
                    clickPiece.getMovementRel().add(relAdd);
                    clickPiece.paintRelCoords();
                    System.out.println("painted");
                }

            }



            //clickPiece.paintRelCoords();
        }
        else {
            //Happens when clickPiece, the tile clicked, has no piece.
            System.out.println("Blank Space");
        }
        //Conceptually: I am trying to know which button has been clicked, what piece is on that button, then check the movement of that piece
        //I need a method to check what piece is on any square (Done, the pieceMap)
        //I need a method to check what movement of any piece is. (Not done, alternative was done)
        //Ask object "what's movement" then return those values as an IntPair
        //Add transparent red squares (JPanel) to board on palette layer. All squares affected should be told they are movemementaffected. (Done, kinda. might need to rework) movement affected not done.
        //this means during buttonclick, they don't run any of the other code


        //Need this to run when button is clicked, but I need it to change based on where the piece is currently and based on what's on the board currently. Not possible in constructor of that piece.
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

    }

    public Board() {

        f.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        javax.swing.ToolTipManager.sharedInstance().setInitialDelay(20);
        makeIconTransparent(imgRed);

        for (int j = 0; j < 8; j++) {
            for (int i = 0; i < 8; i++) {
                if ((j % 2 == 0) && (i % 2 == 0)) {
                    //This code creates a margin with the intsqscales that aren't multiplied and are just added
                    //With the ones multiplied by two, those act as alternating colored squares.
                    //The if else statements check what row they are on, and alternates between margins to accommodate
                    final int index = i;
                    final int indey = j;
                    btnList2d[i][j] = new JButton(imgBeige);
                    btnList2d[i][j].setBounds(intSqScale + intSqScale * i, intSqScale + intSqScale * j, intSqScale, intSqScale);
                    btnList2d[i][j].setBorderPainted(false);
                    btnList2d[i][j].addActionListener(e -> buttonClick(index,indey));
                    filledList2D[i][j] = false;
                    mainPane.add(btnList2d[i][j], JLayeredPane.DEFAULT_LAYER);
                } else if ((j % 2 != 0) && (i % 2 != 0)) {
                    //These are just slightly modified versions of the first one.
                    final int index = i;
                    final int indey = j;
                    btnList2d[i][j] = new JButton(imgBeige);
                    btnList2d[i][j].setBounds(intSqScale + intSqScale * i, intSqScale + intSqScale * j, intSqScale, intSqScale);
                    btnList2d[i][j].setBorderPainted(false);
                    btnList2d[i][j].addActionListener(e -> buttonClick(index,indey));
                    filledList2D[i][j] = false;
                    mainPane.add(btnList2d[i][j], JLayeredPane.DEFAULT_LAYER);
                }
                else if (j % 2 == 0) {
                    final int index = i;
                    final int indey = j;
                    btnList2d[i][j] = new JButton(imgBrown);
                    btnList2d[i][j].setBounds(intSqScale + intSqScale * i, intSqScale + intSqScale * j, intSqScale, intSqScale);
                    btnList2d[i][j].setBorderPainted(false);
                    btnList2d[i][j].addActionListener(e -> buttonClick(index,indey));
                    filledList2D[i][j] = false;
                    mainPane.add(btnList2d[i][j], JLayeredPane.DEFAULT_LAYER);
                } else {
                    final int index = i;
                    final int indey = j;
                    btnList2d[i][j] = new JButton(imgBrown);
                    btnList2d[i][j].setBounds(intSqScale + intSqScale * i, intSqScale + intSqScale * j, intSqScale, intSqScale);
                    btnList2d[i][j].setBorderPainted(false);
                    btnList2d[i][j].addActionListener(e -> buttonClick(index,indey));
                    filledList2D[i][j] = false;
                    mainPane.add(btnList2d[i][j], JLayeredPane.DEFAULT_LAYER);
                }
                btnList2d[i][j].setToolTipText((i) + "," + (j));
            }
        }
        f.setSize(600, 600);
        f.getContentPane().add(mainPane);
        f.setVisible(true);

        //CREATING THE PIECES
        ArrayList<Pawn> pawnListW = new ArrayList<>();
        ArrayList<Pawn> pawnListB = new ArrayList<>();

        for(int i = 0; i < 8; i++){
            //This loop create the 8 pawns at rows 2 and 7
            pawnListW.add(new Pawn(i, 6, true, "pawnListW" +i));
            pieceMap.put(new Pair<>(i, 6), pawnListW.get(i));
            pawnListB.add(new Pawn(i, 1, false, "pawnListB" +i));
            pieceMap.put(new Pair<>(i, 1), pawnListB.get(i));

        }

        Rook rookW1 = new Rook(0, 7, true, "rookW1");
        pieceMap.put(new Pair<>(0, 7), rookW1);
        Rook rookW2 = new Rook(7, 7, true, "rookW2");
        pieceMap.put(new Pair<>(7, 7), rookW2);
        Knight knightW1 = new Knight(1, 7, true, "knightW1");
        pieceMap.put(new Pair<>(1, 7), knightW1);
        Knight knightW2 = new Knight(6, 7, true, "knightW2");
        pieceMap.put(new Pair<>(6, 7), knightW2);
        Bishop bishopW1 = new Bishop(2, 7, true, "bishopW1");
        pieceMap.put(new Pair<>(2, 7), bishopW1);
        Bishop bishopW2 = new Bishop(5, 7, true, "bishopW2");
        pieceMap.put(new Pair<>(5, 7), bishopW2);
        King kingW = new King(4, 7, true, "kingW");
        pieceMap.put(new Pair<>(4, 7), kingW);
        Queen queenW = new Queen(3, 7, true, "queenW");
        pieceMap.put(new Pair<>(3, 7), queenW);
        Rook rookB1 = new Rook(0, 0, false, "rookB1");
        pieceMap.put(new Pair<>(0, 0), rookB1);
        Rook rookB2 = new Rook(7, 0, false, "rookB2");
        pieceMap.put(new Pair<>(7, 0), rookB2);
        Knight knightB1 = new Knight(1, 0, false, "knightB1");
        pieceMap.put(new Pair<>(1, 0), knightB1);
        Knight knightB2 = new Knight(6, 0, false, "knightB2");
        pieceMap.put(new Pair<>(6, 0), knightB2);
        Bishop bishopB1 = new Bishop(2, 0, false, "bishopB1");
        pieceMap.put(new Pair<>(2, 0), bishopB1);
        Bishop bishopB2 = new Bishop(5, 0, false, "bishopB2");
        pieceMap.put(new Pair<>(5, 0), bishopB2);
        King kingB = new King(4, 0, false, "kingB");
        pieceMap.put(new Pair<>(4, 0), kingB);
        Queen queenB = new Queen(3, 0, false, "queenB");
        pieceMap.put(new Pair<>(3, 0), queenB);

    }


}
