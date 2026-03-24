import { createRoot } from "react-dom/client";
import App from "./App.tsx";
import "./index.css";

const style = document.createElement("style");
style.innerHTML = "#lovable-badge { display: none !important; }";
document.head.appendChild(style);

createRoot(document.getElementById("root")!).render(<App />);
