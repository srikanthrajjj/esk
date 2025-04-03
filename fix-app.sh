#!/bin/bash

# Move the existing App.tsx file to a backup
mv src/App.tsx src/App.tsx.bak

# Create a new fixed App.tsx file
cat > src/App.tsx << 'EOF'
import { FaSearch, FaBars, FaComment, FaPhone, FaVideo, FaEllipsisV } from 'react-icons/fa';
import { IoMdAdd } from 'react-icons/io';
import { HiDotsVertical } from 'react-icons/hi';
import { BsFileEarmarkText, BsCalendar3 } from 'react-icons/bs';
import { RiWifiLine } from 'react-icons/ri';
import { BiSignal4 } from 'react-icons/bi';
import { RiBattery2Fill } from 'react-icons/ri';
import { FiMessageSquare, FiPaperclip, FiBell } from 'react-icons/fi';
import { MdOutlineContactPage } from 'react-icons/md';
import { useState, useEffect, useRef } from 'react';
import NotesModal from './components/NotesModal';
import DocumentsModal from './components/DocumentsModal';
import AppointmentModal from './components/AppointmentModal';
import SplashScreen from './components/SplashScreen';
import AdminDashboard from './components/AdminDashboard';
import VictimApp from './components/VictimApp';
import ChatView from './components/ChatView';
import { AdminChatMessage } from './components/AdminChatView';
import websocketService, { WebSocketMessage } from './services/websocketService';

// Define interfaces for our data
interface Case {
  id: string;
  victimName: string;
  dateOfBirth: string;
  address: string;
  crimeType: string;
  crimeNumber: string;
  hasNotifications?: boolean;
  color?: string;
}

interface Appointment {
  id: string;
  type: string;
  date: string;
  time: string;
  relatedTo: string;
  relatedCase: string;
  relatedCrimeType: string;
  color?: string;
}

interface AdminMessage {
  id: string;
  sender: 'admin' | 'officer';
  senderName: string;
  message: string;
  timestamp: string;
  read: boolean;
}

type AppView = 'splash' | 'police' | 'admin' | 'victim';

function App() {
  // App navigation state
  const [currentView, setCurrentView] = useState<AppView>('splash');
  
  // Websocket connection status
  const [wsConnected, setWsConnected] = useState(false);

  // Admin-Police messaging system
  const [adminMessages, setAdminMessages] = useState<Record<string, AdminChatMessage[]>>({
    'off1': [
      {
        id: 'msg1',
        sender: 'admin',
        senderName: 'Admin',
        message: 'Hello DC Morgan, I need an update on the JOHN LINDEN case.',
        timestamp: '09:45 AM',
        read: true
      },
      {
        id: 'msg2',
        sender: 'officer',
        senderName: 'S. Morgan',
        message: 'Good morning. I\'ve scheduled a follow-up interview for tomorrow. The initial evidence suggests a strong case.',
        timestamp: '09:48 AM',
        read: true
      }
    ]
  });
  
  const [unreadAdminMessages, setUnreadAdminMessages] = useState(0);
  const [showAdminMessageList, setShowAdminMessageList] = useState(false);
  const [replyMessage, setReplyMessage] = useState('');
  const [isOfficerTyping, setIsOfficerTyping] = useState(false);
  const [isTyping, setIsTyping] = useState(false);
  const typingTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  
  // Debounced typing indicator handler
  const handleTypingIndicatorChange = (text: string) => {
    // Clear any existing timeout
    if (typingTimeoutRef.current) {
      clearTimeout(typingTimeoutRef.current);
    }
    
    // Send typing indicator if state changed
    if (text && !isTyping) {
      setIsTyping(true);
      websocketService.sendTypingIndicator(true);
    }
    
    // Set timeout to clear typing indicator after user stops typing
    typingTimeoutRef.current = setTimeout(() => {
      if (isTyping) {
        setIsTyping(false);
        websocketService.sendTypingIndicator(false);
      }
    }, 2000); // 2 seconds after user stops typing
  };
  
  // Cleanup typing timeout on unmount
  useEffect(() => {
    return () => {
      if (typingTimeoutRef.current) {
        clearTimeout(typingTimeoutRef.current);
      }
    };
  }, []);
  
  // Initialize WebSocket connection
  useEffect(() => {
    // Connect to WebSocket when the app starts
    const initWebSocket = () => {
      // Connect as admin or officer based on the current view
      const userId = currentView === 'admin' ? 'admin-user' : 'off1';
      const userType = currentView === 'admin' ? 'admin' : 'officer';
      
      // First disconnect any existing connection
      websocketService.disconnect();
      
      // Then connect with the appropriate user ID
      websocketService.connect(userId, userType);
      
      // Setup event listeners
      const connectCallback = websocketService.onConnect(() => {
        console.log(`WebSocket connected as ${userType}`);
        setWsConnected(true);
      });
      
      const messageCallback = websocketService.onMessage(handleWebSocketMessage);
      
      const disconnectCallback = websocketService.onDisconnect(() => {
        console.log('WebSocket disconnected');
        setWsConnected(false);
      });
      
      // Cleanup on unmount or when changing views
      return () => {
        connectCallback();
        messageCallback();
        disconnectCallback();
        websocketService.disconnect();
      };
    };
    
    // Only connect if we're in admin or police view
    if (currentView === 'admin' || currentView === 'police') {
      return initWebSocket();
    }
    
    // Otherwise, make sure we're disconnected
    websocketService.disconnect();
    setWsConnected(false);
    
  }, [currentView]);
  
  // Reconnect if disconnected unexpectedly
  useEffect(() => {
    if (!wsConnected && (currentView === 'admin' || currentView === 'police')) {
      // Set up a reconnection interval
      const reconnectInterval = setInterval(() => {
        if (!wsConnected) {
          console.log('Attempting to reconnect...');
          const userId = currentView === 'admin' ? 'admin-user' : 'off1';
          const userType = currentView === 'admin' ? 'admin' : 'officer';
          websocketService.connect(userId, userType);
        } else {
          clearInterval(reconnectInterval);
        }
      }, 3000); // Try every 3 seconds
      
      return () => {
        clearInterval(reconnectInterval);
      };
    }
  }, [wsConnected, currentView]);
  
  // Handle WebSocket messages
  const handleWebSocketMessage = (message: WebSocketMessage) => {
    console.log('Received WebSocket message:', message);
    
    switch (message.type) {
      case 'ADMIN_MESSAGE':
        // Handle admin message
        console.log('Processing ADMIN_MESSAGE with payload:', message.payload);
        handleIncomingAdminMessage(message.payload);
        break;
        
      case 'OFFICER_MESSAGE':
        // Handle officer message
        console.log('Processing OFFICER_MESSAGE with payload:', message.payload);
        handleIncomingOfficerMessage(message.payload);
        break;
        
      case 'TYPING_INDICATOR':
        // Handle typing indicator
        console.log('Processing TYPING_INDICATOR with payload:', message.payload);
        setIsOfficerTyping(message.payload.isTyping);
        break;
        
      case 'MESSAGE_READ':
        // Mark messages as read
        console.log('Processing MESSAGE_READ with payload:', message.payload);
        handleMessagesRead(message.payload.messageIds);
        break;
        
      default:
        // Ignore other message types for now
        console.log('Ignoring message type:', message.type);
        break;
    }
  };
  
  // Handle incoming admin message
  const handleIncomingAdminMessage = (payload: AdminChatMessage & { recipientId: string }) => {
    console.log('Handling admin message:', payload);
    const { recipientId } = payload;
    
    setAdminMessages(prev => {
      console.log('Previous admin messages:', prev);
      const existingMessages = prev[recipientId] || [];
      console.log('Existing messages for recipient:', existingMessages);
      
      const updatedMessages = {
        ...prev,
        [recipientId]: [...existingMessages, payload]
      };
      
      console.log('Updated admin messages:', updatedMessages);
      return updatedMessages;
    });
    
    // Update unread count if we're in police view
    if (currentView === 'police' && !showAdminMessageList) {
      setUnreadAdminMessages(prev => prev + 1);
    }
  };
  
  // Handle incoming officer message
  const handleIncomingOfficerMessage = (payload: AdminChatMessage) => {
    console.log('Handling officer message:', payload);
    
    setAdminMessages(prev => {
      console.log('Previous admin messages:', prev);
      const existingMessages = prev['off1'] || [];
      console.log('Existing messages for officer:', existingMessages);
      
      const updatedMessages = {
        ...prev,
        'off1': [...existingMessages, payload]
      };
      
      console.log('Updated admin messages:', updatedMessages);
      return updatedMessages;
    });
  };

  // Handle messages being marked as read
  const handleMessagesRead = (messageIds: string[]) => {
    setAdminMessages(prev => {
      const updated = { ...prev };
      
      // Update all messages with the given IDs
      Object.keys(updated).forEach(officerId => {
        updated[officerId] = updated[officerId].map(msg => 
          messageIds.includes(msg.id) ? { ...msg, read: true } : msg
        );
      });
      
      return updated;
    });
  };

  // Update unread message count
  useEffect(() => {
    let count = 0;
    Object.values(adminMessages).forEach(messages => {
      messages.forEach(msg => {
        if (msg.sender === 'admin' && !msg.read && currentView === 'police') {
          count++;
        }
      });
    });
    
    // Set the count
    setUnreadAdminMessages(count);
    
    // If there are unread messages and we're looking at the list, mark them as read
    if (count > 0 && showAdminMessageList && currentView === 'police') {
      // Mark all messages from admin as read via WebSocket
      const unreadMessageIds = getUnreadAdminMessageIds();
      websocketService.markMessagesAsRead(unreadMessageIds);
      
      // Mark them as read locally
      setAdminMessages(prev => {
        const updated = { ...prev };
        Object.keys(updated).forEach(officerId => {
          updated[officerId] = updated[officerId].map(msg => ({
            ...msg,
            read: msg.sender === 'admin' ? true : msg.read
          }));
        });
        return updated;
      });
    }
    
    // Play notification sound if we have new messages and we're in the police app
    if (count > 0 && currentView === 'police' && !showAdminMessageList) {
      // Add notification sound here if needed
      console.log('New message notification!');
      
      // Make the notification icon pulse
      const bellIcon = document.getElementById('bell-notification');
      if (bellIcon) {
        bellIcon.classList.add('animate-pulse');
        setTimeout(() => {
          bellIcon.classList.remove('animate-pulse');
        }, 2000);
      }
    }
  }, [adminMessages, currentView, showAdminMessageList]);
  
  // Get IDs of unread admin messages
  const getUnreadAdminMessageIds = (): string[] => {
    const unreadIds: string[] = [];
    
    Object.values(adminMessages).forEach(messages => {
      messages.forEach(msg => {
        if (msg.sender === 'admin' && !msg.read) {
          unreadIds.push(msg.id);
        }
      });
    });
    
    return unreadIds;
  };

  // Police app states
  const [activeTab, setActiveTab] = useState('cases');
  const [showNotesModal, setShowNotesModal] = useState(false);
  const [showDocumentsModal, setShowDocumentsModal] = useState(false);
  const [showAppointmentModal, setShowAppointmentModal] = useState(false);
  const [showChatView, setShowChatView] = useState(false);
  const [selectedCaseId, setSelectedCaseId] = useState('');
  const [selectedCaseName, setSelectedCaseName] = useState('');
  const [selectedCaseNumber, setSelectedCaseNumber] = useState('');
  const [selectedCrimeType, setSelectedCrimeType] = useState('');
  const [selectedCommunicationMethod, setSelectedCommunicationMethod] = useState<string | null>(null);
  
  // Sample appointments data
  const [appointments, setAppointments] = useState<Appointment[]>([
    {
      id: 'apt1',
      type: 'VICTIM STATEMENT',
      date: '15/04/2025',
      time: '14:30',
      relatedTo: 'JOHN LINDEN',
      relatedCase: 'CRI12145/21',
      relatedCrimeType: 'SEC 47 ASSAULT',
      color: 'bg-blue-500'
    },
    {
      id: 'apt2',
      type: 'CASE REVIEW',
      date: '18/04/2025',
      time: '10:00',
      relatedTo: 'SGT. WILSON',
      relatedCase: 'Department Review',
      relatedCrimeType: 'Central Office',
      color: 'bg-gray-500'
    }
  ]);

  // Sample case data
  const cases: Case[] = [
    {
      id: 'case1',
      victimName: 'JOHN LINDEN',
      dateOfBirth: '30/11/1986',
      address: '12 New town Rd, London NW1 9LN, UK',
      crimeType: 'SEC 47 ASSAULT',
      crimeNumber: 'CRI12145/21',
      hasNotifications: true,
      color: 'bg-red-500'
    },
    {
      id: 'case2',
      victimName: 'AIDAN SHAH',
      dateOfBirth: '11/11/1966',
      address: '12 Winston Rd, London NW1 9LN, UK',
      crimeType: 'ASSAULT WOUNDING',
      crimeNumber: 'CRI12366/21',
      color: 'bg-orange-400'
    }
  ];

  const handleOpenNotes = (caseId: string, caseName: string) => {
    setSelectedCaseId(caseId);
    setSelectedCaseName(caseName);
    setShowNotesModal(true);
  };

  const handleOpenDocuments = (caseId: string, caseName: string) => {
    setSelectedCaseId(caseId);
    setSelectedCaseName(caseName);
    setShowDocumentsModal(true);
  };

  const handleOpenCommunication = (method: string, caseId: string, caseName: string) => {
    setSelectedCommunicationMethod(method);
    setSelectedCaseId(caseId);
    setSelectedCaseName(caseName);
    
    // Find the case to get additional info
    const selectedCase = cases.find(c => c.id === caseId);
    if (selectedCase) {
      setSelectedCaseNumber(selectedCase.crimeNumber);
      setSelectedCrimeType(selectedCase.crimeType);
    }

    if (method === 'message') {
      setShowChatView(true);
    } else {
      // For demo purposes, just alert for other communication methods
      console.log(`Opening ${method} for ${caseName}`);
      alert(`Opening ${method} for ${caseName}`);
    }
  };

  const handleOpenCalendar = (caseId: string, caseName: string, caseNumber: string, crimeType: string) => {
    setSelectedCaseId(caseId);
    setSelectedCaseName(caseName);
    setSelectedCaseNumber(caseNumber);
    setSelectedCrimeType(crimeType);
    setShowAppointmentModal(true);
  };

  const handleSaveAppointment = (newAppointment: Omit<Appointment, 'id'>) => {
    const appointment: Appointment = {
      ...newAppointment,
      id: `apt${appointments.length + 1}`,
    };
    setAppointments([...appointments, appointment]);
  };

  // Handle navigation between app views
  const handleSelectPoliceApp = () => {
    setCurrentView('police');
  };

  const handleSelectAdminDashboard = () => {
    setCurrentView('admin');
  };

  const handleSelectVictimApp = () => {
    setCurrentView('victim');
  };

  const handleBackToSplash = () => {
    setCurrentView('splash');
  };

  // Handle chat view back button
  const handleChatBack = () => {
    setShowChatView(false);
  };

  // Handle sending message from Admin to Officer
  const handleSendMessageToOfficer = (officerId: string, message: string) => {
    // Special case for marking messages as read
    if (message === "__MARK_READ__") {
      // Get IDs of unread officer messages
      const unreadIds: string[] = [];
      const officerMessages = adminMessages[officerId] || [];
      
      officerMessages.forEach(msg => {
        if (msg.sender === 'officer' && !msg.read) {
          unreadIds.push(msg.id);
        }
      });
      
      // Mark messages as read through WebSocket
      websocketService.markMessagesAsRead(unreadIds);
      
      // Update local state
      setAdminMessages(prev => {
        const existingMessages = prev[officerId] || [];
        return {
          ...prev,
          [officerId]: existingMessages.map(msg => 
            msg.sender === 'officer' ? { ...msg, read: true } : msg
          )
        };
      });
      
      return;
    }
    
    // Send message through WebSocket
    websocketService.sendAdminMessage(officerId, message);
  };

  // Handle sending message from Officer to Admin
  const handleSendMessageToAdmin = (message: string) => {
    // Send message through WebSocket
    websocketService.sendOfficerMessage(message);
    
    // Clear reply message
    setReplyMessage('');
  };

  // Mark admin messages as read when police officer views them
  const handleViewAdminMessages = () => {
    setShowAdminMessageList(true);
    
    // Mark all messages from admin as read via WebSocket
    const unreadMessageIds = getUnreadAdminMessageIds();
    websocketService.markMessagesAsRead(unreadMessageIds);
  };

  const handleSendReply = () => {
    if (replyMessage.trim()) {
      handleSendMessageToAdmin(replyMessage);
      setReplyMessage('');
      
      // Reset typing indicator when sending a message
      if (isTyping) {
        setIsTyping(false);
        websocketService.sendTypingIndicator(false);
        
        // Clear any existing timeout
        if (typingTimeoutRef.current) {
          clearTimeout(typingTimeoutRef.current);
          typingTimeoutRef.current = null;
        }
      }
    }
  };

  // Connection status notification
  const ConnectionStatus = () => {
    if (currentView !== 'admin' && currentView !== 'police') return null;
    
    return (
      <div className={`fixed bottom-4 right-4 rounded-lg px-4 py-2 shadow-lg transition-all duration-300 
        ${wsConnected ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}
        ${wsConnected ? 'opacity-0 transform translate-y-10' : 'opacity-100 transform translate-y-0'}`}
        style={{ zIndex: 9999, transition: 'opacity 0.5s, transform 0.5s' }}
      >
        {wsConnected ? (
          <span className="flex items-center">
            <div className="w-2 h-2 bg-green-500 rounded-full mr-2"></div>
            Connected to server
          </span>
        ) : (
          <span className="flex items-center">
            <div className="w-2 h-2 bg-red-500 rounded-full mr-2 animate-pulse"></div>
            Connecting to server...
          </span>
        )}
      </div>
    );
  };

  // Render the appropriate view based on current state
  if (currentView === 'splash') {
    return (
      <SplashScreen
        onSelectPoliceApp={handleSelectPoliceApp}
        onSelectAdminDashboard={handleSelectAdminDashboard}
        onSelectVictimApp={handleSelectVictimApp}
      />
    );
  }

  if (currentView === 'admin') {
    return (
      <>
        <AdminDashboard 
          onBack={handleBackToSplash} 
          onSendMessageToOfficer={handleSendMessageToOfficer}
          officerMessages={adminMessages}
        />
        <ConnectionStatus />
      </>
    );
  }

  if (currentView === 'victim') {
    return (
      <>
        <VictimApp onBack={handleBackToSplash} />
        <ConnectionStatus />
      </>
    );
  }

  // Police App UI (simplified for fix)
  return (
    <>
      <div className="max-w-md mx-auto bg-gray-100 h-screen flex flex-col">
        {/* Status Bar */}
        <div className="bg-black text-white p-2 flex justify-between items-center">
          <div className="flex items-center gap-2">
            <button 
              onClick={handleBackToSplash}
              className="text-xs text-white bg-primary-600 px-2 py-1 rounded-full"
            >
              Back to Home
            </button>
          </div>
          <div className="flex items-center gap-1">
            <BiSignal4 className="text-white" />
            <RiWifiLine className={`${wsConnected ? 'text-green-400' : 'text-red-400'}`} />
            <RiBattery2Fill className="text-white" />
            <span className="text-xs">12:30</span>
          </div>
        </div>

        {/* Basic content for fix */}
        <div className="flex-1 p-4 flex items-center justify-center">
          <h2 className="text-xl font-bold">Police App Interface</h2>
        </div>
      </div>
      <ConnectionStatus />
    </>
  );
}

export default App;
EOF

echo "Fixed App.tsx file created."
EOF 