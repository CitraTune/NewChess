import javax.swing.*;
import java.awt.*;
import java.io.File;
import javax.imageio.ImageIO;
public class DesktopSmoke {
    public static void main(String[] args)throws Exception {
        new File("test-output").mkdirs();
        Chess2.Desktop[] ui=new Chess2.Desktop[1];
        SwingUtilities.invokeAndWait(()->ui[0]=new Chess2.Desktop(new Chess2.Session(new Chess2.Game(42),false,0)));
        SwingUtilities.invokeAndWait(()->{
            Chess2.Desktop d=ui[0];
            int cell=Math.min(d.board.getWidth(),d.board.getHeight())/8;
            if(cell<=0)throw new AssertionError("Board did not lay out");
            d.board.click(cell/2,6*cell+cell/2);
            d.board.click(cell/2,5*cell+cell/2);
            Chess2.check(d.s.g.turn==1&&d.s.g.at(0,5)!=null,"desktop move failed");
        });
        Rectangle bounds=ui[0].frame.getBounds();
        ImageIO.write(new Robot().createScreenCapture(bounds),"png",new File("test-output/desktop.png"));
        SwingUtilities.invokeAndWait(()->ui[0].frame.dispose());
        System.out.println("PASS desktop window, layout, selection, move and render");
    }
}
