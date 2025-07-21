To undo a highlight in the syncfusion_flutter_pdfviewer, you need to utilize the UndoHistoryController. By assigning an instance of this controller to the undoController property of the SfPdfViewer, you can then use its undo method to revert the last annotation change, which includes highlights. The canUndo property allows you to check if an undo operation is currently possible. 
Here's how to implement it:
Initialize the UndoHistoryController:
Code

   final UndoHistoryController _undoController = UndoHistoryController();
Assign the controller to the SfPdfViewer:
Code

   SfPdfViewer.network(
     'your_pdf_url',
     undoController: _undoController,
   )
Enable Undo/Redo in the UI (e.g., using buttons):
Code

   ValueListenableBuilder(
     valueListenable: _undoController,
     builder: (context, value, child) {
       return IconButton(
         onPressed: _undoController.value.canUndo ? _undoController.undo : null,
         icon: const Icon(Icons.undo),
       );
     },
   )
This code snippet demonstrates how to create an IconButton that triggers the undo method when pressed, but only if canUndo is true. You can adapt this to your specific UI needs. 